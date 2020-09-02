// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'utils.dart';

class APIWrapper {
  // maybe saveFiles in saveObject and json.encode values?

  Future<bool> saveFiles(Map files) async {
    setString('uploaded_files', json.encode(files));
    return true;
  }

  Future<bool> setString(String name, String content) async {
    try {
      html.window.localStorage[name] = content;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map> getFiles() async =>
      json.decode(await getString('uploaded_files', '{}'));

  Future<String> getString(String name, String defaultValue) async =>
      html.window.localStorage[name] ?? defaultValue;

  Future<bool> getBool(String name) async =>
      html.window.localStorage[name] ?? false;

  Future<bool> setBool(String name, bool value) async {
    try {
      html.window.localStorage[name] = json.encode(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> copy(String text) async {
    print('called APIWrapper.copy($text)');
    html.InputElement input = html.document.createElement('input');
    input.type = 'text';
    input.value = text;
    input.setSelectionRange(0, 50);
    html.document.body.append(input);
    input.select();
    bool copyStatus = html.document.execCommand('copy');
    input.remove();
    return copyStatus;
  }

  Future<Map> getFile() async {
    html.InputElement inputFile = html.document.createElement('input');
    inputFile.type = 'file';
    html.document.body.append(inputFile);
    inputFile.click();
    await inputFile.onChange.first;
    if (inputFile.files.length == 0) return null;
    html.File file = inputFile.files[0];
    inputFile.remove();
    inputFile = null;
    return {'realFile': file, 'size': file.size, 'name': file.name};
  }

  bool isWebAndroid() {
    print(html.window.navigator.userAgent);
    return html.window.navigator.userAgent.contains('Android');
  }

  void downloadApp() => html.window.location
      .replace('https://github.com/Pato05/uploadgram-app/releases/latest');
  Future<Map> importFiles() async {
    Map fileMap = await getFile();
    if (fileMap == null) return null;
    html.File file = fileMap['realFile'];
    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    Uint8List bytes = Uint8List.view(reader.result);
    if (String.fromCharCode(bytes.first) != '{' ||
        String.fromCharCode(bytes.last) != '}') return null;
    Map files = json.decode(String.fromCharCodes(bytes));
    return files;
  }

  Future<void> saveFile(String filename, String content) async {
    html.Blob blob = new html.Blob([content]);
    html.LinkElement a = html.document.createElement('a');
    String url = a.href = html.Url.createObjectUrlFromBlob(blob);
    a.setAttribute('download', filename);
    html.document.body.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
    return;
  }

  Future<Map> uploadFile(
    Map file, {
    Function(int, int) onProgress,
    Function() onError,
    Function onStart,
    Function onEnd,
  }) async {
    print(file);
    if (!(file['realFile'] is html.File &&
        (file['size'] is int || file['size'] is double) &&
        file['name'] is String))
      throw UnsupportedError('Non-valid file map provided for the upload.');

    html.HttpRequest xhr = html.HttpRequest();
    html.FormData formData = html.FormData();
    formData.append('file_size', file['size'].toString());
    formData.appendBlob('file_upload', file['realFile']);
    xhr.open('POST', 'https://uploadgram.me/upload');
    xhr.upload.onProgress
        .listen((html.ProgressEvent e) => onProgress(e.loaded, e.total));
    xhr.onError.listen((e) => onError());
    xhr.onLoadStart.listen((e) => onStart());
    xhr.send(formData);
    await xhr.onLoadEnd.first;
    if (xhr.status == 200) {
      onEnd();
      return json.decode(xhr.responseText);
    }
    return {
      'ok': false,
      'statusCode': xhr.status,
      'message': 'Error ${xhr.status}: ${xhr.statusText}',
    };
  }

  Future<Map> deleteFile(String file) async {
    html.HttpRequest xhr = html.HttpRequest();
    xhr.open('GET', 'https://uploadgram.me/delete/$file');
    xhr.send();
    await xhr.onLoad.first;
    if (xhr.status == 200) return json.decode(xhr.responseText);
    return {
      'ok': false,
      'statusCode': xhr.status,
      'message': xhr.statusText,
    };
  }

  Future<Map> renameFile(String file, String newName) async {
    html.HttpRequest xhr = html.HttpRequest();
    html.window.console.log(xhr);
    xhr.open('POST', 'https://uploadgram.me/rename/$file');
    xhr.send(json
        .encode(<String, String>{'new_filename': await parseName(newName)}));
    await xhr.onLoad.first;
    if (xhr.status == 200) return json.decode(xhr.responseText);
    var jsonError;
    if (xhr.responseText.substring(0, 1) == '{')
      jsonError = json.decode(xhr.responseText);
    var altMessage = 'Error ${xhr.status}: ${xhr.statusText}';
    return {
      'ok': false,
      'statusCode': xhr.status,
      'message':
          jsonError == null ? altMessage : (jsonError['message'] ?? altMessage),
    };
  }
}
