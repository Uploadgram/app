import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share/share.dart';

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
    Map? files = await compute((File file) async {
      return json.decode(
        await file.readAsString())
    }, file); // returns null if the file is not valid
    return files is Map ? files : null;
  }

  Future<Map> getFiles() async {
    Map files = json.decode(await getString('uploaded_files', '{}'));
    String? lastUri = await _methodChannel.invokeMethod('getLastUrl');
    if (lastUri != null) {
      Uri uri = Uri.parse(lastUri);
      if (uri.hasFragment) {
        Map? importedFiles =
            await Utils.parseFragment(Uri.decodeComponent(uri.fragment));
        if (importedFiles != null) files.addAll(importedFiles);
      }
    }
    return files;
  }

  Future<String> getString(String name, String defaultValue) async =>
      (await _methodChannel.invokeMethod('getString',
          <String, String>{'name': name, 'default': defaultValue})) as String;

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
  Future<void> deleteCachedFile(String name) =>
      _methodChannel.invokeMethod('deleteCachedFile',<String, String> {
        'name': name
      });

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

  Future<void> deletePreferences() =>
      _methodChannel.invokeMethod('deletePreferences');

      Future<void> shareUploadgramLink(String url) async => Share.share(url);
}
