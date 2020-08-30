// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util';
import 'dart:async';
import 'dart:convert';
import 'package:file_picker_web/file_picker_web.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils.dart';

class APIWrapper {
  void dispose() => null;

  Future<Map> getFile() async {
    html.File file = await FilePicker.getFile();
    return {'realFile': file, 'size': file.size, 'name': file.name};
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
    /** @ */
    html.File realFile = file['realFile'];

    html.HttpRequest xhr = html.HttpRequest();
    html.FormData formData = html.FormData();
    formData.append('file_size', file['size'].toString());
    formData.appendBlob('file_upload', file['realFile']);
    xhr.open('POST', 'https://uploadgram.me/upload');
    // TODO: find out how to show progress
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
      'statusCode': 400,
      'message': 'An error occurred',
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
      'statusMessage': xhr.statusText,
      'message': xhr.statusText
    };
  }

  Future<Map> renameFile(String file, String newName) async {
    html.HttpRequest xhr = html.HttpRequest();
    html.window.console.log(xhr);
    xhr.open('POST', 'https://uploadgram.me/rename/$file');
    xhr.send(json.encode({'new_name': parseName(newName)}));
    await xhr.onLoad.first;
    if (xhr.status == 200) return json.decode(xhr.responseText);
    return {
      'ok': false,
      'statusCode': xhr.status,
      'statusMessage': xhr.statusText,
      'message': xhr.statusText
    };
  }

  Future<void> migrateFiles() async {
    if (html.window.localStorage.keys.contains('uploaded_files')) {
      var sharedPreferences = await SharedPreferences.getInstance();
      sharedPreferences.setString(
          'uploaded_files', html.window.localStorage['uploaded_files']);
      html.window.localStorage.remove('uploaded_files');
    }
  }
}
