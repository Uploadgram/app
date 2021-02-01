// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'utils.dart';

class APIWrapper {
  // importing files is handled by the javascript part.

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

  Future<Map> getFiles() async {
    try {
      String files = await getString('uploaded_files', '{}');
      if (files != 'e') return json.decode(files);
      return {'error': true};
    } catch (e) {
      return {};
    }
  }

  Future<String> getString(String name, String defaultValue) async {
    try {
      return html.window.localStorage[name] ?? defaultValue;
    } catch (e) {
      return 'e';
    }
  }

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
    html.InputElement input = html.TextInputElement();
    var range = html.Range();
    input.value = text;
    input.contentEditable = 'contentEditable';
    range.selectNodeContents(input);
    var sel = html.window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    input.setSelectionRange(0, 100);
    html.document.body.append(input);
    input.select();
    bool copyStatus = html.document.execCommand('copy');
    input.remove();
    return copyStatus;
  }

  Future<Map> askForFile([String type]) {
    var completer = Completer<Map>();
    html.FileUploadInputElement inputFile = html.FileUploadInputElement();
    if (type != null) inputFile.accept = type;
    html.document.body.append(inputFile);
    inputFile.click();
    inputFile.onChange.listen((_) {
      if (inputFile.files.length == 0) return null;
      html.File file = inputFile.files[0];
      inputFile.remove();
      inputFile = null;
      completer
          .complete({'realFile': file, 'size': file.size, 'name': file.name});
    });
    inputFile.onAbort.listen((_) => completer.complete(null));
    return completer.future;
  }

  bool isWebAndroid() => html.window.navigator.userAgent.contains('Android');

  void downloadApp() => html.window.location
      .replace('https://github.com/Pato05/uploadgram-app/releases/latest');
  Future<Map> importFiles() async {
    Map fileMap = await askForFile();
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
    Function(double, double) onProgress,
    Function(int) onError,
  }) {
    var completer = Completer<Map>();
    print(file);
    if (!(file['realFile'] is html.File &&
        (file['size'] is int || file['size'] is double) &&
        file['name'] is String))
      throw UnsupportedError('Non-valid file map provided for the upload.');

    html.HttpRequest xhr = html.HttpRequest();
    html.FormData formData = html.FormData();
    formData.append('file_size', file['size'].toString());
    formData.appendBlob('file_upload', file['realFile']);
    xhr.open('POST', 'https://api.uploadgram.me/upload');
    var initDate;
    xhr.upload.onProgress.listen((html.ProgressEvent e) {
      onProgress.call(
          e.loaded / e.total,
          e.loaded /
              (DateTime.now().millisecondsSinceEpoch -
                  initDate.millisecondsSinceEpoch) *
              1000);
    });
    xhr.onError.listen((e) {
      onError(xhr.status);
      completer.complete({
        'ok': false,
        'statusCode': xhr.status,
        'message': 'Error ${xhr.status}: ${xhr.statusText}',
      });
    });
    xhr.onLoadEnd.listen((e) {
      if (xhr.status == 200)
        completer.complete(json.decode(xhr.responseText));
      else
        completer.complete({
          'ok': false,
          'statusCode': xhr.status,
          'message': 'Error ${xhr.status}: ${xhr.statusText}',
        });
    });
    initDate = DateTime.now();
    xhr.send(formData);
    return completer.future;
  }

  Future<Map> deleteFile(String file) async {
    var req = await html.window.fetch('https://api.uploadgram.me/delete/$file');

    if (req.status == 200) return await req.json();
    return {
      'ok': false,
      'statusCode': req.status,
      'message': req.statusText,
    };
  }

  Future<Map> renameFile(String file, String newName) async {
    var req =
        await html.window.fetch('https://api.uploadgram.me/rename/$file', {
      'method': 'POST',
      'body': json
          .encode(<String, String>{'new_filename': await parseName(newName)})
    });
    if (req.status == 200) return await req.json();
    var reqText = await req.text();
    var jsonError;
    if (reqText.substring(0, 1) == '{') jsonError = json.decode(reqText);
    var altMessage = 'Error ${req.status}: ${req.statusText}';
    return {
      'ok': false,
      'statusCode': req.status,
      'message':
          jsonError == null ? altMessage : (jsonError['message'] ?? altMessage),
    };
  }

  Future<bool> checkNetwork() async {
    var response = await html.window
        .fetch('https://api.uploadgram.me/', {'redirect': 'manual'});
    if (response.status >= 500) {
      return false;
    }
    return true;
  }
}
