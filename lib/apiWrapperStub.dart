// we have two different api wrappers because while in android we are using Dio
// to make requests, on the web we will be using XMLHttpRequest, since Dio
// doesn't include some needed features yet.
class APIWrapper {
  bool copy(String text, {Function onSuccess, Function onError}) =>
      throw UnsupportedError('');

  bool isWebAndroid() => throw UnsupportedError('');
  void downloadApp() => throw UnsupportedError('');
  Future<Map> importFiles() => throw UnsupportedError('');

  Future<Map> getFile() => throw UnsupportedError('');
  Future<bool> saveFile(String filename, String content) =>
      throw UnsupportedError('');
  Future<bool> saveFiles(Map files) => throw UnsupportedError('');
  Future<Map> getFiles() => throw UnsupportedError('');

  Future<Map> uploadFile(
    Map file, {
    Function(int, int) onProgress,
    Function() onError,
    Function onStart,
    Function onEnd,
  }) =>
      throw UnsupportedError('');

  Future<Map> deleteFile(String delete) => throw UnsupportedError('');
  Future<Map> renameFile(String delete, String newName) =>
      throw UnsupportedError('');
}
