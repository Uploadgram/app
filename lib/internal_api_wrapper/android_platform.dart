import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../app_logic.dart';

class InternalAPIWrapper {
  final MethodChannel _methodChannel =
      const MethodChannel('com.pato05.uploadgram');

  Future<bool> copy(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  bool isWebAndroid() => false;

  Future<Map?> importFiles() async {
    Map fileMap = await (askForFile() as FutureOr<Map<dynamic, dynamic>>);
    File file = fileMap['realFile'];
    Map? files = json.decode(
        await file.readAsString()); // returns null if the file is not valid
    return files;
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
    Map files = {};
    files = json.decode(await getString('uploaded_files', '{}'));
    String? u = await _methodChannel.invokeMethod('getLastUrl');
    if (u != null) {
      Uri uri = Uri.parse(u);
      if (uri.hasFragment) {
        String fragment = Uri.decodeComponent(uri.fragment);
        print(fragment);
        if (fragment.indexOf('import:') == 0) {
          String filesMap = fragment.substring(7);
          print(filesMap);
          if (filesMap.substring(0, 1) == '{') {
            try {
              Map parsedFiles = json.decode(filesMap);
              parsedFiles.forEach((key, value) {
                if (key.length == 48 || key.length == 49) {
                  files[key] = value;
                }
              });
            } catch (e) {}
          } else {
            print('trying new import method...');
            if (fragment.length == 48 || fragment.length == 49) {
              Map file = await AppLogic.webApi.getFile(fragment);
              if (file != {}) {
                file.remove('mime');
                files[fragment] = file;
              }
            }
          }
          saveFiles(files);
        }
      }
    }
    return files;
  }

  Future<String> getString(String name, String defaultValue) async =>
      (await _methodChannel.invokeMethod('getString',
          <String, String>{'name': name, 'default': defaultValue})) as String;

  Future<bool> getBool(String name) async => (await _methodChannel
      .invokeMethod('getBool', <String, String>{'name': name})) as bool;

  Future<bool> setBool(String name, bool value) async =>
      (await _methodChannel.invokeMethod(
          'setBool', <String, dynamic>{'name': name, 'value': value})) as bool;

  Future<Map?> askForFile([String type = '*/*']) async {
    String? filePath = await _methodChannel
        .invokeMethod('getFile', <String, String>{'type': type});
    print(filePath);
    if (filePath == 'PERMISSION_NOT_GRANTED') {
      return {'error': 'PERMISSION_NOT_GRANTED'};
    }
    if (filePath == null) return null;
    File file = File(filePath);
    return {
      'realFile': file,
      'size': await file.length(),
      'name': file.path.split('/').last,
    };
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
}
