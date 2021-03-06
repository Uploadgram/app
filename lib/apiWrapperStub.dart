// we have two different api wrappers because while in android we are using Dio
// to make requests, on the web we will be using XMLHttpRequest, since Dio
// doesn't include some needed features yet.
class APIWrapper {
  Future<bool> copy(String? text, {Function? onSuccess, Function? onError}) =>
      throw UnsupportedError('');

  bool isWebAndroid() => throw UnsupportedError('');
  void downloadApp() => throw UnsupportedError('');
  Future<Map?> importFiles() => throw UnsupportedError('');

  Future<Map?> getFile() => throw UnsupportedError('');
  Future<Map?> askForFile() => throw UnsupportedError('');
  Future<bool?> saveFile(String? filename, String content) =>
      throw UnsupportedError('');
  Future<bool> saveFiles(Map? files) => throw UnsupportedError('');
  Future<Map> getFiles() => throw UnsupportedError('');
  Future<bool> setString(String name, String? content) =>
      throw UnsupportedError('');
  Future<String> getString(String name, String defaultValue) =>
      throw UnsupportedError('');

  Future<bool> getBool(String name) => throw UnsupportedError('');
  Future<bool> setBool(String name, bool content) => throw UnsupportedError('');

  Future<Map> uploadFile(
    Map file, {
    Function(double, double, String)? onProgress,
    Function(int)? onError,
  }) =>
      throw UnsupportedError('');

  Future<Map> deleteFile(String delete) => throw UnsupportedError('');
  Future<Map> renameFile(String delete, String newName) =>
      throw UnsupportedError('');
  Future<bool> checkNetwork() => throw UnsupportedError('');
}
