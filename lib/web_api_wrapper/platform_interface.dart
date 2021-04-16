export ''
    if (dart.library.io) 'android_platform.dart'
    if (dart.library.html) 'web_platform.dart';

import 'package:uploadgram/web_api_wrapper/api_definitions.dart';

class WebAPIWrapper {
  Future<UploadApiResponse> uploadFile(
    Map file, {
    Function(double, double, String)? onProgress,
    Function(int)? onError,
  }) =>
      throw UnsupportedError('uploadFile() has not been implemented.');

  Future<Map> deleteFile(String delete) =>
      throw UnsupportedError('deleteFile() has not been implemented.');
  Future<RenameApiResponse> renameFile(String delete, String newName) =>
      throw UnsupportedError('renameFile() has not been implemented.');
  Future<bool> checkNetwork() =>
      throw UnsupportedError('checkNetwork() has not been implemented.');

  Future<Map> getFile(String deleteId) =>
      throw UnsupportedError('getFile() has not been implemented.');
  void downloadApp() =>
      throw UnsupportedError('downloadApp() has not been implemented.');
}
