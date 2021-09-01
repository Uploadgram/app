import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/main.dart';
import 'package:uploadgram/utils.dart';

class InternalAPIWrapper {
  static final instance = InternalAPIWrapper._();
  factory InternalAPIWrapper() => instance;
  InternalAPIWrapper._();

  static final isAndroid = Platform.isAndroid;
  static const isNative = true;

  static String? lastUri; // just needed for web

  static final _logger = Logger('InternalAPIWrapper, Native');

  final MethodChannel _methodChannel =
      const MethodChannel('com.pato05.uploadgram');

  late LazyBox<UploadgramLogRecord> _loggingBox;
  LazyBox<UploadgramLogRecord> get loggingBox => _loggingBox;

  Future<bool> copy(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  bool isWebAndroid() => false;

  static Map<String, Map<String, dynamic>>? _decodeFileContents(File file) {
    String contents = file.readAsStringSync();
    Object? decoded = jsonDecode(contents);
    if (decoded is Map) {
      return decoded.cast<String, Map<String, dynamic>>();
    }
  }

  Future<Map<String, Map<String, dynamic>>?> importFiles() async {
    final uploadgramFile = await askForFile();
    if (uploadgramFile == null) return null;
    File file = uploadgramFile.realFile;
    _logger.info(
        'importing file list from ${uploadgramFile.name} at ${file.path}');
    Map<String, Map<String, dynamic>>? files = await compute(
        _decodeFileContents, file); // returns null if the file is not valid
    _logger.finest('isolate returned $files');
    return files;
  }

  Future<Map<String, dynamic>?> getImportedFiles() async {
    String? lastUri = await _methodChannel.invokeMethod('getLastUrl');
    if (lastUri != null) {
      _logger.info('app was opened with uri "$lastUri"');
      Uri uri = Uri.parse(lastUri);
      if (uri.hasFragment) {
        Map<String, dynamic>? importedFiles =
            await Utils.parseFragment(Uri.decodeComponent(uri.fragment));
        return importedFiles;
      }
    }
  }

  Future<String> getString(String name, String defaultValue) async =>
      (await _methodChannel.invokeMethod('getString',
          <String, String>{'name': name, 'default': defaultValue})) as String;

  Future<UploadgramFile<File>?> askForFile([String type = '*/*']) async {
    final result = await FilePicker.platform.pickFiles(allowCompression: false);
    if (result == null) return null;
    final file = result.files.first;
    return UploadgramFile(
      realFile: File(file.path!),
      size: file.size,
      name: file.name,
    );
  }

  Future<void> clearFilesCache() => FilePicker.platform.clearTemporaryFiles();

  Future<bool?> saveFileFromFile(String filename, String fromFile,
          {required String type}) =>
      _methodChannel.invokeMethod<bool>('saveFileFromFile', <String, String>{
        'filename': filename,
        'file': fromFile,
        'type': type
      });

  Future<bool?> saveFile(String filename, String content,
      {required String type}) async {
    Directory cacheDir = await getTemporaryDirectory();
    final tempDir = await cacheDir.createTemp();
    final file = await File('${tempDir.path}${Platform.pathSeparator}content')
        .writeAsString(content);
    return await saveFileFromFile(filename, file.path, type: type);
  }

  Future<bool?> exportFiles(Map<String, UploadedFile> files) {
    if (files.length == 1) {
      return saveFile(
          files.entries.first.value.name + '.json', jsonEncode(files),
          type: 'application/json');
    }
    return compute<Map<String, Map>, String>(jsonEncode,
            files.map((key, value) => MapEntry(key, value.toJson())))
        .then((value) =>
            saveFile('uploadgram_files.json', value, type: 'application/json'));
  }

  static void listenDropzone(
          BuildContext context, Function(UploadgramFile) uploadFile) =>
      throw UnsupportedError('listenDropzone() has not been implemented.');

  Future<void> deletePreferences() =>
      _methodChannel.invokeMethod('deletePreferences');

  Future<Color?> getAccent() => _methodChannel
      .invokeMethod('getAccent')
      .then((value) => value == null ? null : Color(value));

  Future<bool> installAPK(String path) => _methodChannel.invokeMethod<bool>(
      'installAPK', <String, String>{'path': path}).then((res) => res ?? false);

  /// Returns a list of ABIs
  Future<List<String>?> getDeviceAbiList() =>
      _methodChannel.invokeListMethod<String>('getDeviceAbiList');

  Future<void> clearLogs() async => _loggingBox.clear();

  Future<bool> saveLogs() async {
    final tmp = await getTemporaryDirectory();
    final file =
        File('${tmp.path}${Platform.pathSeparator}uploadgram_logs.txt');
    for (final key in _loggingBox.keys) {
      final entry = (await _loggingBox.get(key))!;
      await file.writeAsString(jsonEncode(entry) + '\n', mode: FileMode.append);
    }
    await saveFileFromFile('uploadgram_logs.txt', file.path,
        type: 'text/plain');
    await file.delete();
    return true;
  }

  static const _logPortName = 'logging_port';
  static late bool _isIsolate;
  Future<void> setupLogger() async {
    Hive
      ..registerAdapter(UploadgramLogRecordAdapter())
      ..registerAdapter(LevelAdapter());
    _loggingBox = await Hive.openLazyBox('logs');
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_logPortName);
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _logPortName);
    receivePort.listen((message) {
      _log(message as UploadgramLogRecord);
    });
    _isIsolate = false;
  }

  Future<void> setupLoggerIsolate() async {
    preSetupLogger();
    _isIsolate = true;
    _logger.info('setting up logger for isolate');
  }

  final logLock = Lock();
  void log(LogRecord _) {
    final record = UploadgramLogRecord.fromLogRecord(_);
    if (!_isIsolate) {
      _log(record);
    } else {
      IsolateNameServer.lookupPortByName(_logPortName)?.send(record);
    }
  }

  void _log(UploadgramLogRecord record) {
    assert(() {
      // ignore: avoid_print
      print(record.format());

      return true;
    }());
    logLock.synchronized(() => _loggingBox.add(record));
  }
}
