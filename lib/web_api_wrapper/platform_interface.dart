import 'dart:async';

import 'package:uploadgram/api_definitions.dart';

class WebAPIWrapper {
  static final instance = WebAPIWrapper._();
  factory WebAPIWrapper() => instance;
  WebAPIWrapper._();

  Future<void> enqueueUpload(UploadgramFile file) =>
      throw UnsupportedError('uploadFile() has not been implemented.');

  Future<DeleteApiResponse> deleteFile(String delete) =>
      throw UnsupportedError('deleteFile() has not been implemented.');
  Future<RenameApiResponse> renameFile(String delete, String newName) =>
      throw UnsupportedError('renameFile() has not been implemented.');
  Future<bool> checkNetwork() =>
      throw UnsupportedError('checkNetwork() has not been implemented.');

  Future<Map?> getFile(String deleteId) =>
      throw UnsupportedError('getFile() has not been implemented.');
  void downloadApp() =>
      throw UnsupportedError('downloadApp() has not been implemented.');

  FutureOr<void> ensureInitialized() =>
      throw UnsupportedError('ensureInitialized() has not been implemented.');

  List<UploadingFile> get queue =>
      throw UnsupportedError('getter queue has not been implemented.');

  FutureOr<void> cancelUpload(String taskId) =>
      throw UnsupportedError('cancelUpload() has not been implemented');
}
