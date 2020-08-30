// we have two different api wrappers because while in android we are using Dio
// to make requests, on the web we will be using XMLHttpRequest, since Dio
// doesn't include some needed features yet.
class APIWrapper {
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
  Future<dynamic> getFile() => throw UnsupportedError('');
  Future<void> migrateFiles() => throw UnsupportedError('');
}
