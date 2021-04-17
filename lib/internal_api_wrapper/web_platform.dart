// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/utils.dart';

class InternalAPIWrapper {
  static String? lastUri;
  static bool overlayMounted = false;
  static bool isDropzoneListening = false;

  InternalAPIWrapper() {
    html.document.onContextMenu.listen((event) =>
        event.preventDefault()); // disable normal browser right click
  }

  static void listenDropzone(
      BuildContext context, Function(UploadgramFile) uploadFile) {
    if (isDropzoneListening) return;
    isDropzoneListening = true;
    final theme = Theme.of(context);
    final dropOverlay = OverlayEntry(
      builder: (BuildContext context) => Positioned.fill(
          child: Container(
        color: Color.fromRGBO(0, 0, 0, 0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_upload, size: 78),
            Text(
              'Drop your file here!',
              style: theme.textTheme.bodyText1?.copyWith(
                fontSize: 42,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      )),
    );
    [html.document.onDragEnter, html.document.onDragOver]
        .forEach((element) => element.listen((event) {
              event.preventDefault();
              if (!overlayMounted) {
                Overlay?.of(context)?.insert(dropOverlay);
                overlayMounted = true;
              }
            }));
    html.document.onDragLeave.listen((event) {
      event.preventDefault();
      if (overlayMounted) {
        dropOverlay.remove();
        overlayMounted = false;
      }
    });
    html.document.onDrop.listen((event) {
      event.preventDefault();
      event.stopPropagation();
      if (overlayMounted) {
        dropOverlay.remove();
        overlayMounted = false;
      }
      if (event.dataTransfer.files == null) return;
      if (event.dataTransfer.files!.length > 0) {
        uploadFile.call(UploadgramFile(
          realFile: event.dataTransfer.files![0],
          size: event.dataTransfer.files![0].size,
          name: event.dataTransfer.files![0].name,
        ));
      }
    });
  }

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
    Map files = json.decode(await getString('uploaded_files', '{}'));
    if (lastUri != null) {
      Map? importedFiles =
          await Utils.parseFragment(Uri.decodeComponent(lastUri!));
      if (importedFiles != null) {
        files.addAll(importedFiles);
        saveFiles(files);
      }
    }
    return files;
  }

  Future<String> getString(String name, String defaultValue) async {
    return html.window.localStorage[name] ?? defaultValue;
  }

  Future<bool> getBool(String name) async {
    if (html.window.localStorage[name] == null) return false;
    return json.decode(html.window.localStorage[name]!) ?? false;
  }

  Future<bool> setBool(String name, bool value) async {
    try {
      html.window.localStorage[name] = json.encode(value);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> copy(String text) async {
    if (!html.document.queryCommandSupported("copy")) return false;
    html.TextInputElement input = html.TextInputElement();
    html.Range range = html.Range();
    input.value = text;
    input.contentEditable = 'true';
    html.document.body!.append(input);
    range.selectNodeContents(input);
    html.Selection? sel = html.window.getSelection();
    sel?.removeAllRanges();
    sel?.addRange(range);
    input.select();
    input.setSelectionRange(0, text.length);
    bool copyStatus = html.document.execCommand('copy');
    input.remove();
    return copyStatus;
  }

  Future<UploadgramFile> askForFile([String? type]) {
    var completer = Completer<UploadgramFile>();
    html.FileUploadInputElement inputFile = html.FileUploadInputElement();
    if (type != null) inputFile.accept = type;
    html.document.body!.append(inputFile);
    inputFile.click();
    inputFile.onChange.listen((_) {
      if (inputFile.files!.length == 0) return null;
      html.File? file = inputFile.files![0];
      inputFile.remove();
      completer.complete(
          UploadgramFile(realFile: file, size: file.size, name: file.name));
    });
    inputFile.onAbort.listen((_) => completer
        .complete(UploadgramFile(error: UploadgramFileError.abortedByUser)));
    return completer.future;
  }

  bool isWebAndroid() => html.window.navigator.userAgent.contains('Android');

  Future<Map?> importFiles() async {
    UploadgramFile uploadgramFile = await askForFile();
    if (uploadgramFile.hasError()) return null;
    html.File file = uploadgramFile.realFile;
    html.FileReader reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    Uint8List bytes = Uint8List.view(reader.result as ByteBuffer);
    Map? files = json.decode(String.fromCharCodes(bytes));
    return files is Map ? files : null;
  }

  Future<void> clearFilesCache() async => null;

  Future<bool?> saveFile(String filename, String content) async {
    print('[web] saveFile called');
    html.Blob blob = new html.Blob([content]);
    html.AnchorElement a = html.AnchorElement();
    String url = a.href = html.Url.createObjectUrlFromBlob(blob);
    a.setAttribute('download', filename);
    html.document.body!.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  }
}
