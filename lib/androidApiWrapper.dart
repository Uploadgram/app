import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'utils.dart';
import 'package:http_parser/http_parser.dart';

class APIWrapper {
  Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    validateStatus: (status) => true,
  ));
  final MethodChannel _methodChannel =
      const MethodChannel('com.pato05.uploadgram');

  Future<bool> copy(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  bool isWebAndroid() => false;
  void downloadApp() => null;
  Future<Map> importFiles() async {
    Map fileMap = await getFile('application/json');
    File file = fileMap['realFile'];
    Uint8List fileBytes = await file.readAsBytes();
    if (String.fromCharCode(fileBytes.first) != '{' ||
        String.fromCharCode(fileBytes.last) != '}') return null;
    Map files = json.decode(String.fromCharCodes(fileBytes));
    return files;
  }

  Future<bool> saveFiles(Map files) {
    print('called api.saveFiles($files)');
    return setString('uploaded_files', json.encode(files));
  }

  Future<bool> setString(String name, String content) =>
      _methodChannel.invokeMethod(
          'saveString', <String, String>{'name': name, 'content': content});

  Future<Map> getFiles() async {
    Map files = {};
    files = json.decode(await getString('uploaded_files', '{}'));
    String u = await _methodChannel.invokeMethod('getLastUrl');
    if (u != null) {
      print(u);
      Uri uri = Uri.parse(u);
      if (uri.hasFragment) {
        String fragment = Uri.decodeComponent(uri.fragment);
        print(fragment);
        if (fragment.indexOf('import:') == 0) {
          String filesMap = uri.fragment.substring(8);
          try {
            Map parsedFiles = json.decode(filesMap);
            parsedFiles.forEach((key, value) {
              if (key.length == 48 || key.length == 49) {
                files[key] = value;
              }
            });
          } catch (e) {}
          saveFiles(files);
        }
      }
    }
    return files;
  }

  Future<String> getString(String name, String defaultValue) =>
      _methodChannel.invokeMethod(
          'getString', <String, String>{'name': name, 'default': defaultValue});

  Future<bool> getBool(String name) =>
      _methodChannel.invokeMethod('getBool', <String, String>{'name': name});

  Future<bool> setBool(String name, bool value) => _methodChannel
      .invokeMethod('setBool', <String, dynamic>{'name': name, 'value': value});

  Future<Map> getFile([String type = '*/*']) async {
    String filePath = await _methodChannel
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

  Future<void> saveFile(String filename, String content) async {
    String filePath = await _methodChannel
        .invokeMethod('saveFile', <String, String>{'filename': filename});
    if (filePath == null) return;
    await File(filePath).writeAsString(content);
    return;
  }

  Future<Map> uploadFile(
    Map file, {
    Function(int, int) onProgress,
    Function() onError,
    Function() onStart,
    Function() onEnd,
  }) async {
    //if (!await file.exists())
    //  return {
    //    'ok': 'false',
    //    'statusCode': 400,
    //    'message': 'The file does not exist.'
    //  };
    if (!(file['realFile'] is File &&
        (file['size'] is int || file['size'] is double) &&
        file['name'] is String))
      throw UnsupportedError('Non-valid file map provided for the upload.');

    String fileName = file['name'];
    int fileSize = file['size'];
    MediaType mime = mimeTypes[fileName.split('.').last.toLowerCase()] ??
        MediaType('application', 'octet-stream');
    print(mime);
    print('processing file upload');
    FormData formData = FormData.fromMap({
      'file_size': fileSize,
      'file_upload': await MultipartFile.fromFile(file['realFile'].path,
          filename: file['name'], contentType: mime),
    });
    onStart();
    print('uploading file');
    Response response = await _dio.post('https://api.uploadgram.me/upload',
        data: formData, onSendProgress: onProgress);
    print('end file upload');
    if (response.statusCode != 200) {
      onError();
      return null;
    }
    onEnd();
    return response.data;
  }

  Future<Map> deleteFile(String file) async {
    Response response =
        await _dio.get('https://api.uploadgram.me/delete/$file');
    if (response.statusCode != 200) {
      return {
        'ok': false,
        'statusCode': response.statusCode,
      };
    }
    return response.data;
  }

  Future<Map> renameFile(String file, String newName) async {
    Response response = await _dio.post(
        'https://api.uploadgram.me/rename/$file',
        data: {'new_filename': await parseName(newName)});
    if (response.statusCode != 200) {
      return {
        'ok': false,
        'statusCode': response.statusCode,
        'message': response.data['message'] ??
            'Error ${response.statusCode}: ${response.statusMessage}'
      };
    }
    return response.data;
  }
}
