import 'dart:async';

import 'package:flutter/material.dart';

import 'internal_api_wrapper/platform_instance.dart';
import 'web_api_wrapper/platform_instance.dart';
import 'app_settings.dart';

class AppLogic {
  static Map<String, Map>? files;
  static InternalAPIWrapper platformApi = InternalAPIWrapper();
  static WebAPIWrapper webApi = WebAPIWrapper();

  static List<String> selected = [];
  static List<Map> uploadingQueue = [];

  static Future<Map<String?, dynamic>?> getFiles() async {
    if (files == null) {
      Map _ = await platformApi.getFiles();
      if (_.containsKey('error')) {
        return {};
      }
      files = _.cast<String, Map>();
    }
    return files;
  }

  static Future<bool> saveFiles() async {
    if (files == null) return false;
    return await platformApi.saveFiles(files!);
  }

  static Stream? uploadFileStream(UniqueKey? key, Map file) {
    if (file['locked'] == true) return null;
    file['locked'] = true;
    var controller = StreamController.broadcast();
    () async {
      // this while loop could be probably improved or removed
      while (uploadingQueue[0]['key'] != key) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await webApi.uploadFile(
        file,
        onProgress: (double progress, double bytesPerSec, String remaining) {
          controller.add({
            'type': 'progress',
            'value': {'progress': progress, 'bytesPerSec': bytesPerSec}
          });
        },
      );
      if (result['ok']) {
        var fileObj = {
          'filename': file['name'],
          'size': file['size'],
          'url': result['url'],
        };
        files![result['delete']] = fileObj;
        controller.add({
          'type': 'end',
          'value': {'file': fileObj, 'delete': result['delete']},
        });
        saveFiles();
      } else {
        String? _error = 'An error occurred while obtaining the response';
        if (result['statusCode'] > 500)
          _error = 'We are having server problems. Try again later.';
        if (result.containsKey('message')) _error = result['message'];
        controller.add({
          'type': 'errorEnd',
          'value': _error,
        });
      }
      controller.close();
      uploadingQueue.removeAt(0);
      if (uploadingQueue.length == 0) platformApi.clearFilesCache();
    }();
    return controller.stream;
  }
}
