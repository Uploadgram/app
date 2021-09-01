// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

import 'package:synchronized/synchronized.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/utils.dart';

class WebAPIWrapper {
  static final instance = WebAPIWrapper._();
  factory WebAPIWrapper() => instance;
  WebAPIWrapper._();

  final _uploadLock = Lock();
  final List<UploadingFile> _queue = [];

  Future<void> enqueueUpload(UploadgramFile file) async {
    _uploadLock.synchronized(() => _uploadFile(file));
  }

  List<UploadingFile> get queue => _queue;

  Future<void> _uploadFile(UploadgramFile file) {
    var completer = Completer<UploadApiResponse>();
    print(file);
    if (!(file.realFile is html.File && file.size > 0)) {
      throw UnsupportedError('Non-valid file map provided for the upload.');
    }

    html.HttpRequest xhr = html.HttpRequest();
    html.FormData formData = html.FormData();
    formData.append('file_size', file.size.toString());
    formData.appendBlob('file_upload', file.realFile);
    xhr.open('POST', 'https://${settings.endpoint.api}/upload');
    late DateTime initDate;
    xhr.upload.onProgress.listen((html.ProgressEvent e) {
      int bytesPerSec = (e.loaded! /
              (DateTime.now().millisecondsSinceEpoch -
                  initDate.millisecondsSinceEpoch) *
              1000)
          .toInt();
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
      if (xhr.status == 200) {
        completer.complete(
            UploadApiResponse.fromJson(json.decode(xhr.responseText!)));
      } else {
        if (!completer.isCompleted) {
          completer.complete(UploadApiResponse(
              ok: false,
              statusCode: xhr.status!,
              errorMessage: 'Error ${xhr.status}: ${xhr.statusText}'));
        }
      }
    });
    initDate = DateTime.now();
    xhr.send(formData);
    return completer.future;
  }

  Future<DeleteApiResponse> deleteFile(String file) async {
    var completer = Completer<DeleteApiResponse>();
    html.HttpRequest xhr = html.HttpRequest();
    xhr.open('GET', 'https://${settings.endpoint.api}/delete/$file');
    xhr.send();
    xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        completer.complete(
            DeleteApiResponse.fromJson(json.decode(xhr.responseText!)));
      } else if (!completer.isCompleted) {
        completer
            .complete(DeleteApiResponse(ok: false, statusCode: xhr.status!));
      }
    });
    xhr.onError.listen((_) => completer
        .complete(DeleteApiResponse(ok: false, statusCode: xhr.status!)));
    return await completer.future;
  }

  Future<RenameApiResponse> renameFile(String file, String newName) async {
    var completer = Completer<RenameApiResponse>();
    html.HttpRequest xhr = html.HttpRequest();
    xhr.open('POST', 'https://${settings.endpoint.api}/rename/$file');
    xhr.send(json.encode(
        <String, String>{'new_filename': await Utils.parseName(newName)}));
    var handleError = () {
      Map? jsonError;
      if (xhr.responseText!.substring(0, 1) == '{') {
        jsonError = json.decode(xhr.responseText!);
      }
      var altMessage = 'Error ${xhr.status}: ${xhr.statusText}';
      return RenameApiResponse(
          ok: false,
          statusCode: xhr.status!,
          errorMessage: jsonError == null
              ? altMessage
              : (jsonError['message'] ?? altMessage));
    };
    xhr.onLoad.listen((_) {
      if (xhr.status! == 200) {
        completer.complete(
            RenameApiResponse.fromJson(json.decode(xhr.responseText!)));
      } else {
        handleError.call();
      }
    });
    xhr.onError.listen((_) => handleError.call());
    return await completer.future;
  }

  Future<bool> checkNetwork() async {
    print('[web] checkNetwork() called');
    Completer<bool> completer = Completer<bool>();
    html.HttpRequest xhr = html.HttpRequest()
      ..open('HEAD', 'https://${settings.endpoint.api}/status');
    xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        completer.complete(true);
      } else {
        completer.complete(false);
      }
    });
    xhr.onError.listen((_) => completer.complete(false));
    xhr.send();
    return await completer.future;
  }

  Future<Map?> getFile(String deleteId) async {
    Completer<Map?> completer = Completer<Map?>();
    html.HttpRequest xhr = html.HttpRequest()
      ..open('GET', 'https://${settings.endpoint.api}/get/$deleteId');
    xhr.onLoad.listen((_) {
      if (xhr.status == 200) {
        completer.complete(json.decode(xhr.responseText!));
      } else {
        completer.complete({});
      }
    });
    xhr.onError.listen((_) => completer.complete(null));
    xhr.send();
    return await completer.future;
  }

  void downloadApp() => html.window.location
      .replace('https://github.com/Pato05/uploadgram-app/releases/latest');
}
