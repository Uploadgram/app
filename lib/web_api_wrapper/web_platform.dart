// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

import 'package:uploadgram/web_api_wrapper/api_definitions.dart';

import '../utils.dart';

class WebAPIWrapper {
  Future<UploadApiResponse> uploadFile(
    Map file, {
    Function(double, double, String)? onProgress,
    Function(int?)? onError,
  }) {
    var completer = Completer<UploadApiResponse>();
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
    late DateTime initDate;
    xhr.upload.onProgress.listen((html.ProgressEvent e) {
      double bytesPerSec = e.loaded! /
          (DateTime.now().millisecondsSinceEpoch -
              initDate.millisecondsSinceEpoch) *
          1000;
      int secondsRemaining = (e.total! - e.loaded!) ~/ bytesPerSec;
      String stringRemaining = (secondsRemaining >= 3600
              ? (secondsRemaining ~/= 3600).toString() + ' hours '
              : '') +
          (secondsRemaining >= 60
              ? (secondsRemaining = secondsRemaining % 3600 ~/ 60).toString() +
                  ' minutes '
              : '');
      // just to avoid having 'remaining' as string
      stringRemaining = stringRemaining +
          ((secondsRemaining > 0 || stringRemaining.isEmpty)
              ? '${secondsRemaining % 60} seconds '
              : '') +
          'remaining';
      onProgress?.call(e.loaded! / e.total!, bytesPerSec, stringRemaining);
    });
    xhr.onError.listen((e) {
      onError?.call(xhr.status);

      completer.complete(UploadApiResponse(
          ok: false,
          statusCode: xhr.status!,
          errorMessage: 'Error ${xhr.status}: ${xhr.statusText}'));
    });
    xhr.onLoadEnd.listen((e) {
      if (xhr.status == 200)
        completer.complete(
            UploadApiResponse.fromJson(json.decode(xhr.responseText!)));
      else
        completer.complete(UploadApiResponse(
            ok: false,
            statusCode: xhr.status!,
            errorMessage: 'Error ${xhr.status}: ${xhr.statusText}'));
    });
    initDate = DateTime.now();
    xhr.send(formData);
    return completer.future;
  }

  Future<Map> deleteFile(String file) async {
    var completer = Completer<Map>();
    html.HttpRequest xhr = html.HttpRequest();
    xhr.open('GET', 'https://api.uploadgram.me/delete/$file');
    xhr.send();
    xhr.onLoad.listen((_) {
      if (xhr.status == 200)
        completer.complete(json.decode(xhr.responseText!));
      else
        completer.complete({
          'ok': false,
          'statusCode': xhr.status,
          'message': xhr.statusText,
        });
    });
    xhr.onError.listen((_) => completer.complete({
          'ok': false,
          'statusCode': xhr.status,
          'message': xhr.statusText,
        }));
    return await completer.future;
  }

  Future<RenameApiResponse> renameFile(String file, String newName) async {
    var completer = Completer<RenameApiResponse>();
    html.HttpRequest xhr = html.HttpRequest();
    xhr.open('POST', 'https://api.uploadgram.me/rename/$file');
    xhr.send(json.encode(
        <String, String>{'new_filename': await Utils.parseName(newName)}));
    var handleError = () {
      var jsonError;
      if (xhr.responseText!.substring(0, 1) == '{')
        jsonError = json.decode(xhr.responseText!);
      var altMessage = 'Error ${xhr.status}: ${xhr.statusText}';
      return RenameApiResponse(
          ok: false,
          statusCode: xhr.status!,
          errorMessage: jsonError == null
              ? altMessage
              : (jsonError['message'] ?? altMessage));
    };
    xhr.onLoad.listen((_) {
      if (xhr.status == 200)
        completer.complete(json.decode(xhr.responseText!));
      else
        handleError.call();
    });
    xhr.onError.listen((_) => handleError.call());
    return await completer.future;
  }

  Future<bool> checkNetwork() async {
    print('[web] checkNetwork() called');
    Completer<bool> completer = Completer<bool>();
    html.HttpRequest xhr = html.HttpRequest()
      ..open('HEAD', 'https://api.uploadgram.me/status');
    xhr.onLoad.listen((_) {
      if (xhr.status == 200)
        completer.complete(true);
      else
        completer.complete(false);
    });
    xhr.onError.listen((_) => completer.complete(false));
    xhr.send();
    return await completer.future;
  }

  Future<Map> getFile(String deleteId) async {
    Completer<Map> completer = Completer<Map>();
    html.HttpRequest xhr = html.HttpRequest()
      ..open('GET', 'https://api.uploadgram.me/get/$deleteId');
    xhr.onLoad.listen((_) {
      if (xhr.status == 200)
        completer.complete(json.decode(xhr.responseText!));
      else
        completer.complete({});
    });
    xhr.onError.listen((_) => completer.complete({}));
    xhr.send();
    return await completer.future;
  }

  void downloadApp() => html.window.location
      .replace('https://github.com/Pato05/uploadgram-app/releases/latest');
}
