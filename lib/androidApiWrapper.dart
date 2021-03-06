import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'utils.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class APIWrapper {
  Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    validateStatus: (status) => true,
  ));
  final MethodChannel _methodChannel =
      const MethodChannel('com.pato05.uploadgram');
  final FlutterLocalNotificationsPlugin _flutterNotifications =
      FlutterLocalNotificationsPlugin();
  bool _didInitializeNotifications = false;
  int _uploadNotificationId = 1;

  Future<bool> copy(String text) async {
    Clipboard.setData(ClipboardData(text: text));
    return true;
  }

  bool isWebAndroid() => false;
  void downloadApp() => null;

  Future<Map> importFiles() async {
    Map fileMap = await askForFile();
    File file = fileMap['realFile'];
    Map files = json.decode(
        await file.readAsString()); // returns null if the file is not valid
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
              Map file = await getFile(fragment);
              file.remove('mime');
              files[fragment] = file;
            }
          }
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

  Future<Map> askForFile([String type = '*/*']) async {
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

  Future<void> clearFilesCache() =>
      _methodChannel.invokeMethod('clearFilesCache');

  Future<void> saveFile(String filename, String content) async {
    String filePath = await _methodChannel
        .invokeMethod('saveFile', <String, String>{'filename': filename});
    if (filePath == null) return;
    if (filePath.startsWith('/data/data')) return;
    await File(filePath).writeAsString(content);
    return;
  }

  Future<Map> getFile(String deleteID) async {
    Response response =
        await _dio.get('https://api.uploadgram.me/get/$deleteID');
    try {
      return json.decode(response.data);
    } catch (e) {
      return {};
    }
  }

  Future<Map> uploadFile(
    Map file, {
    Function(double, double, String) onProgress,
    Function(int) onError,
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
    print('preparing notification...');
    if (!_didInitializeNotifications) {
      const AndroidInitializationSettings androidInitializationSettings =
          AndroidInitializationSettings('icon_64');
      _flutterNotifications.initialize(
          InitializationSettings(android: androidInitializationSettings));
      _didInitializeNotifications = true;
    }
    _flutterNotifications.show(
        0,
        fileName,
        'Connecting...',
        NotificationDetails(
            android: AndroidNotificationDetails(
          'com.pato05.uploadgram/notifications/upload',
          'Upload progress notification',
          'Upload status and progress notifications',
          channelShowBadge: true,
          importance: Importance.max,
          priority: Priority.high,
          onlyAlertOnce: true,
          showProgress: true,
          ongoing: true,
          indeterminate: true,
        )));

    print('processing file upload');
    //uploader.enqueue(MultipartFormDataUpload(
    //  url: 'https://api.uploadgram.me/upload',
    //  files: [FileItem(path: file['realFile'].path, field: 'file_upload')],
    //  method: UploadMethod.POST,
    //  data: {'file_size': fileSize.toString()},
    //));
    //uploader.progress.listen((p) {
    //  var notif = NotificationDetails(
    //      android: AndroidNotificationDetails(
    //          'com.pato05.uploadgram/notifications/upload',
    //          'Upload progress notification',
    //          'Upload status and progress notifications',
    //          channelShowBadge: true,
    //          importance: Importance.max,
    //          priority: Priority.high,
    //          onlyAlertOnce: true,
    //          showProgress: true,
    //          maxProgress: 100,
    //          progress: p.progress));
    //  _flutterNotifications.show(0, 'Uploading file...', '$fileName', notif);
    //  onProgress((p.progress * fileSize ~/ 100), fileSize);
    //});
    //uploader.result.listen((result) {
    //  if (result.statusCode != 200)
    //    completer.complete({
    //      'ok': false,
    //      'statusCode': result.statusCode,
    //      'message': 'Error ${result.statusCode}'
    //    });
    //  completer.complete(json.decode(result.response));
    //});
    //return await completer.future;
    FormData formData = FormData.fromMap({
      'file_size': fileSize,
      'file_upload': await MultipartFile.fromFile(file['realFile'].path,
          filename: file['name'], contentType: mime),
    });
    print('uploading file');
    var initDate = DateTime.now();
    var notifTitle = fileName.length > 25
        ? '${fileName.substring(0, 17)}...${fileName.substring(fileName.length - 8)}'
        : fileName;

    int _lastUploadedBytes = 0;
    Response response = await _dio.post('https://api.uploadgram.me/upload',
        data: formData, onSendProgress: (loaded, total) {
      var bytesPerSec = loaded /
          (DateTime.now().millisecondsSinceEpoch -
              initDate.millisecondsSinceEpoch) *
          1000;
      var progress = loaded / total;
      int secondsRemaining = (total - loaded) ~/ bytesPerSec;
      String stringRemaining = (secondsRemaining >= 3600
              ? (secondsRemaining ~/ 3600).toString() + ' hours '
              : '') +
          ((secondsRemaining %= 3600) >= 60
              ? (secondsRemaining ~/ 60).toString() + ' minutes '
              : '');
      // just to avoid having 'remaining' as string
      stringRemaining = stringRemaining +
          ((secondsRemaining > 0 || stringRemaining.isEmpty)
              ? '${secondsRemaining % 60} seconds '
              : '') +
          'remaining';
      print(secondsRemaining);
      if (loaded - _lastUploadedBytes > bytesPerSec ~/ 100)
        _flutterNotifications.show(
            0,
            notifTitle,
            '${humanSize(bytesPerSec)}/s - ${(progress * 100).toStringAsFixed(0)}%',
            NotificationDetails(
                android: AndroidNotificationDetails(
                    'com.pato05.uploadgram/notifications/upload',
                    'Upload progress notification',
                    'Upload status and progress notifications',
                    subText: stringRemaining,
                    channelShowBadge: true,
                    importance: Importance.defaultImportance,
                    priority: Priority.high,
                    onlyAlertOnce: true,
                    showProgress: true,
                    playSound: false,
                    ongoing: true,
                    maxProgress: total,
                    progress: loaded)));
      onProgress(progress, bytesPerSec, stringRemaining);
    });
    print('end file upload');
    _flutterNotifications.cancel(0);
    _flutterNotifications.show(
        _uploadNotificationId++,
        'Upload completed!',
        fileName,
        NotificationDetails(
            android: AndroidNotificationDetails(
                'com.pato05.uploadgram/notifications/upload_completed',
                'Upload completed notification',
                'File upload completed notification',
                channelShowBadge: true,
                importance: Importance.max,
                priority: Priority.high,
                setAsGroupSummary: true,
                onlyAlertOnce: false)));
    clearFilesCache();
    if (response.statusCode != 200) {
      onError(response.statusCode);
      return {
        'ok': false,
        'statusCode': response.statusCode,
        'message': 'Error ${response.statusCode}: ${response.statusMessage}',
      };
    }
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

  Future<bool> checkNetwork() async {
    Response response = await _dio.head('https://api.uploadgram.me/status');
    if (response.statusCode != 200) {
      return false;
    }
    return true;
  }
}
