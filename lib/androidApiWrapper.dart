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

  bool copy(String text, {Function onSuccess, Function onError}) {
    Clipboard.setData(ClipboardData(text: text));
    if (onSuccess != null) onSuccess();
    return true;
  }

  bool isWebAndroid() => false;
  void downloadApp() => null;
  Future<Map> importFiles() async {
    Map fileMap = await getFile();
    File file = fileMap['realFile'];
    Uint8List fileBytes = await file.readAsBytes();
    if (String.fromCharCode(fileBytes.first) != '{' ||
        String.fromCharCode(fileBytes.last) != '}') return null;
    Map files = json.decode(String.fromCharCodes(fileBytes));
    return files;
  }

  Future<bool> saveFiles(Map files) =>
      saveString('uploaded_files', json.encode(files));

  Future<bool> saveString(String name, String content) =>
      _methodChannel.invokeMethod(
          'saveString', <String, String>{'name': name, 'content': content});

  Future<Map> getFiles() async =>
      json.decode(await getString('uploaded_files', '{}'));

  Future<String> getString(String name, String defaultValue) =>
      _methodChannel.invokeMethod(
          'getString', <String, String>{'name': name, 'default': defaultValue});

  Future<Map> getFile() async {
    String filePath = await _methodChannel.invokeMethod('getFile');
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
    MediaType mime = mimeTypes[fileName.split('.').last] ??
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
    Response response = await _dio.post('https://uploadgram.me/upload',
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
    Response response = await _dio.get('https://uploadgram.me/delete/$file');
    if (response.statusCode != 200) {
      return {
        'ok': false,
        'statusCode': response.statusCode,
      };
    }
    return response.data;
  }

  Future<Map> renameFile(String file, String newName) async {
    Response response = await _dio.post('https://uploadgram.me/rename/$file',
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
