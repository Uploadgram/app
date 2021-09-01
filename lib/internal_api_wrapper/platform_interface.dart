import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_logic.dart';

class InternalAPIWrapper {
  static String? lastUri; // Exclusive to web

  static const isAndroid = false;
  static const isNative = false;

  static final instance = InternalAPIWrapper._();
  factory InternalAPIWrapper() => instance;
  InternalAPIWrapper._();
  //Future<bool> copy(String? text, {Function? onSuccess, Function? onError}) =>
  //    throw UnsupportedError('copy() has not been implemented.');

  bool isWebAndroid() =>
      throw UnsupportedError('isWebAndroid() has not been implemented.');
  Future<Map?> importFiles() =>
      throw UnsupportedError('importFiles() has not been implemented.');
  Future<void> clearFilesCache() =>
      throw UnsupportedError('clearFilesCache() has not been implemented.');

  Future<UploadgramFile?> askForFile() =>
      throw UnsupportedError('askForFile() has not been implemented.');
  Future<bool?> saveFile(String? filename, String content,
          {required String type}) =>
      throw UnsupportedError('saveFile() has not been implemented.');
  Future<bool?> exportFiles(Map<String, UploadedFile> files) =>
      throw UnsupportedError('exportFiles() has not been implemented.');

  Future<Map<String, dynamic>?> getImportedFiles() =>
      throw UnsupportedError('getImportedFiles() has not been implemented.');
  Future<String?> getString(String name, String defaultValue) =>
      throw UnsupportedError('getString() has not been implemented.');

  static void listenDropzone(
          BuildContext context, Function(UploadgramFile) uploadFile) =>
      throw UnsupportedError('listenDropzone() has not been implemented.');

  Future<void> deletePreferences() =>
      throw UnsupportedError('deletePreferences() has not been implemented.');

  Future<Color> getAccent() =>
      throw UnsupportedError('getAccent() has not been implemented.');

  Future<void> setupLogger() =>
      throw UnsupportedError('setupLogger() has not been implemented.');
  void log(LogRecord record) =>
      throw UnsupportedError('log() has not been implemented.');
}
