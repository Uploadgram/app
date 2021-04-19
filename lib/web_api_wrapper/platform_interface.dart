import 'package:uploadgram/api_definitions.dart';

class WebAPIWrapper {
  Future<UploadApiResponse> uploadFile(
    UploadgramFile file, {
    Function(double, int, String)? onProgress,
    Function(int)? onError,
  }) =>
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
}
