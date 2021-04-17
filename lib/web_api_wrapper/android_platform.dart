import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/mime_types.dart';

class WebAPIWrapper {
  Dio _dio = Dio(BaseOptions(
    followRedirects: true,
    validateStatus: (status) => true,
  ));
  final FlutterLocalNotificationsPlugin _flutterNotifications =
      FlutterLocalNotificationsPlugin();
  bool _didInitializeNotifications = false;
  int _uploadNotificationId = 1;

  void downloadApp() => null;

  Future<Map> getFile(String deleteId) async {
    Response response =
        await _dio.get('https://api.uploadgram.me/get/$deleteId');
    try {
      return json.decode(response.data);
    } catch (e) {
      return {};
    }
  }

  Future<UploadApiResponse> uploadFile(
    UploadgramFile file, {
    Function(double, double, String)? onProgress,
    Function? onError,
  }) async {
    if (!(file.realFile is File && file.size > 0))
      throw UnsupportedError('Non-valid file map provided for the upload.');
    MediaType mime = mimeTypes[file.name.split('.').last.toLowerCase()] ??
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
    if (file.size > 500000)
      _flutterNotifications.show(
          0,
          file.name,
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
            color: Colors.blue,
          )));

    print('processing file upload');
    FormData formData = FormData.fromMap({
      'file_size': file.size,
      'file_upload': await MultipartFile.fromFile(file.realFile.path,
          filename: file.name, contentType: mime),
    });
    print('uploading file');
    var initDate = DateTime.now();
    var notifTitle = file.name.length > 25
        ? '${file.name.substring(0, 17)}...${file.name.substring(file.name.length - 8)}'
        : file.name;

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
      if (loaded - _lastUploadedBytes > bytesPerSec ~/ 100 &&
          file.size > 500000)
        _flutterNotifications.show(
            0,
            notifTitle,
            '${Utils.humanSize(bytesPerSec)}/s - ${(progress * 100).toStringAsFixed(0)}%',
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
              progress: loaded,
              color: Colors.blue,
            )));
      onProgress?.call(progress, bytesPerSec, stringRemaining);
    });
    print('end file upload');
    _flutterNotifications.cancel(0);
    _flutterNotifications.show(
        _uploadNotificationId++,
        'Upload completed!',
        file.name,
        NotificationDetails(
            android: AndroidNotificationDetails(
          'com.pato05.uploadgram/notifications/upload_completed',
          'Upload completed notification',
          'File upload completed notification',
          channelShowBadge: true,
          importance: Importance.max,
          priority: Priority.high,
          setAsGroupSummary: true,
          onlyAlertOnce: false,
          color: Colors.blue,
        )));
    if (response.statusCode != 200) {
      onError?.call(response.statusCode);
      return UploadApiResponse(
          ok: false,
          statusCode: response.statusCode!,
          errorMessage:
              'Error ${response.statusCode}: ${response.statusMessage}');
    }
    return UploadApiResponse.fromJson(response.data);
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

  Future<RenameApiResponse> renameFile(String file, String newName) async {
    Response response = await _dio.post(
        'https://api.uploadgram.me/rename/$file',
        data: {'new_filename': await Utils.parseName(newName)});
    if (response.statusCode != 200) {
      return RenameApiResponse(
          ok: false,
          statusCode: response.statusCode!,
          errorMessage: response.data['message'] ??
              'Error ${response.statusCode}: ${response.statusMessage}');
    }
    return RenameApiResponse.fromJson(response.data);
  }

  Future<bool> checkNetwork() async {
    Response response = await _dio.head('https://api.uploadgram.me/status');
    if (response.statusCode != 200) {
      return false;
    }
    return true;
  }
}
