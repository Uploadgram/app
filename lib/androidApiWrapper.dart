import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'utils.dart';
import 'package:http_parser/http_parser.dart';

class APIWrapper {
  Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    validateStatus: (status) => status < 500,
  ));

  Future<Map> getFile() async {
    File file = await FilePicker.getFile(allowCompression: false);
    if (file == null) return null;
    return {
      'realFile': file,
      'size': await file.length(),
      'name': file.path.split('/').last,
    };
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
    MediaType mime =
        mimeTypes[fileName.split('.').last] ?? 'application/octet-stream';
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
        'statusMessage': response.statusMessage,
      };
    }
    return response.data;
  }

  Future<Map> renameFile(String file, String newName) async {
    Response response = await _dio.post('https://uploadgram.me/rename/$file',
        data: {'new_name': parseName(newName)});
    if (response.statusCode != 200) {
      return {
        'ok': false,
        'statusCode': response.statusCode,
        'statusMessage': response.statusMessage,
      };
    }
    return response.data;
  }

  Future<void> migrateFiles() => null;
}
