import 'dart:async';

import 'package:flutter/services.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';

class AppLogic {
  static Map<String, Map>? files;
  static InternalAPIWrapper platformApi = InternalAPIWrapper();
  static WebAPIWrapper webApi = WebAPIWrapper();

  static List<String> selected = [];
  static List<UploadingFile> uploadingQueue = [];

  static Future<Map<String, dynamic>?> getFiles() async {
    if (files == null) {
      Map _ = await platformApi.getFiles();
      files = _.cast<String, Map>();
    }
    return files;
  }

  static Future<bool> saveFiles() async {
    if (files == null) return false;
    return await platformApi.saveFiles(files!);
  }

  static Future<bool> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text)).then((value) => true);

  static Stream<UploadingEvent>? uploadFileStream(UploadingFile file) {
    if (file.locked == true) return null;
    file.locked = true;
    var controller = StreamController<UploadingEvent>.broadcast();
    () async {
      // this while loop could be probably improved or removed
      while (uploadingQueue[0].fileKey != file.fileKey) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await webApi.uploadFile(
        file.uploadgramFile,
        onProgress: (double progress, double bytesPerSec, String remaining) {
          controller.add(UploadingEventProgress(
              progress: progress, bytesPerSec: bytesPerSec));
        },
      );
      if (result.ok) {
        var fileObj = {
          'filename': file.uploadgramFile.name,
          'size': file.uploadgramFile.size,
          'url': result.url,
        };
        files![result.delete!] = fileObj;
        controller
            .add(UploadingEventEnd(delete: result.delete!, file: fileObj));
        saveFiles();
      } else {
        String? _error = 'An error occurred while obtaining the response';
        if (result.statusCode > 500)
          _error = 'We are having server problems. Try again later.';
        if (result.errorMessage != null) _error = result.errorMessage;
        controller.addError({'message': _error});
      }
      controller.close();
      uploadingQueue.removeAt(0);
      if (uploadingQueue.length == 0) platformApi.clearFilesCache();
    }();
    return controller.stream;
  }
}
