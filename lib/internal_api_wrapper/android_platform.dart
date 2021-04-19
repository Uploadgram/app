import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/utils.dart';

class InternalAPIWrapper {
  static String? lastUri; // just needed for web

  final MethodChannel _methodChannel =
      const MethodChannel('com.pato05.uploadgram');

  Future<bool> copy(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  bool isWebAndroid() => false;

  Future<Map?> importFiles() async {
    UploadgramFile uploadgramFile = await askForFile();
    if (uploadgramFile.hasError()) return null;
    File file = uploadgramFile.realFile!;
    Map? files = json.decode(
        await file.readAsString()); // returns null if the file is not valid
    return files is Map ? files : null;
  }

  Future<bool> saveFiles(Map files) {
    print('called api.saveFiles($files)');
    return setString('uploaded_files', json.encode(files));
  }

  Future<bool> setString(String name, String content) async =>
      (await _methodChannel.invokeMethod(
              'saveString', <String, String>{'name': name, 'content': content}))
          as bool;

  Future<Map> getFiles() async {
    Map files = json.decode(await getString('uploaded_files', '{}'));
    String? lastUri = await _methodChannel.invokeMethod('getLastUrl');
    if (lastUri != null) {
      Uri uri = Uri.parse(lastUri);
      if (uri.hasFragment) {
        Map? importedFiles =
            await Utils.parseFragment(Uri.decodeComponent(uri.fragment));
        if (importedFiles != null) files.addAll(importedFiles);
        saveFiles(files);
      }
    }
    return files;
  }

  Future<String> getString(String name, String defaultValue) async =>
      (await _methodChannel.invokeMethod('getString',
          <String, String>{'name': name, 'default': defaultValue})) as String;

  Future<bool> getBool(String name, bool defaultValue) async =>
      (await _methodChannel.invokeMethod('getBool',
          <String, dynamic>{'name': name, 'default': defaultValue})) as bool;

  Future<bool> setBool(String name, bool value) async =>
      (await _methodChannel.invokeMethod(
          'setBool', <String, dynamic>{'name': name, 'value': value})) as bool;

  Future<UploadgramFile> askForFile([String type = '*/*']) async {
    String? filePath = await _methodChannel
        .invokeMethod('getFile', <String, String>{'type': type});
    if (filePath == 'PERMISSION_NOT_GRANTED') {
      return UploadgramFile(error: UploadgramFileError.permissionNotGranted);
    }
    if (filePath == null)
      return UploadgramFile(error: UploadgramFileError.abortedByUser);
    File file = File(filePath);
    return UploadgramFile(
      realFile: file,
      size: await file.length(),
      name: file.path.split('/').last,
    );
  }

  Future<void> clearFilesCache() =>
      _methodChannel.invokeMethod('clearFilesCache');

  Future<bool?> saveFile(String filename, String content) async {
    String? filePath = await _methodChannel
        .invokeMethod('saveFile', <String, String>{'filename': filename});
    if (filePath == null) return null;
    if (filePath.startsWith('/data/data')) return null;
    await File(filePath).writeAsString(content);
    return true;
  }

  static void listenDropzone(
          BuildContext context, Function(UploadgramFile) uploadFile) =>
      throw UnsupportedError('listenDropzone() has not been implemented.');
}
