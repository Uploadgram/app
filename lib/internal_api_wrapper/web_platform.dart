// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/utils.dart';

class InternalAPIWrapper {
  static final instance = InternalAPIWrapper._();
  factory InternalAPIWrapper() => instance;

  InternalAPIWrapper._() {
    html.document.onContextMenu.listen((event) =>
        event.preventDefault()); // disable normal browser right click
  }

  static const isAndroid = false;
  static const isNative = false;

  static String? lastUri;
  static bool overlayMounted = false;
  static bool isDropzoneListening = false;

  static void listenDropzone(
      BuildContext context, Function(UploadgramFile) uploadFile) {
    if (isDropzoneListening) return;
    isDropzoneListening = true;
    final theme = Theme.of(context);
    final dropOverlay = OverlayEntry(
      builder: (BuildContext context) => Positioned.fill(
          child: Container(
        color: const Color.fromRGBO(0, 0, 0, 0.4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload, size: 78),
            Text(
              AppLocalizations.of(context).dropzoneDropFilesHere,
              style: theme.textTheme.bodyText1?.copyWith(
                fontSize: 42,
                fontWeight: FontWeight.w500,
              ),
            )
          ],
        ),
      )),
    );
    for (var element in [html.document.onDragEnter, html.document.onDragOver]) {
      element.listen((event) {
        event.preventDefault();
        if (!overlayMounted) {
          Overlay?.of(context)?.insert(dropOverlay);
          overlayMounted = true;
        }
      });
    }
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
      if (event.dataTransfer.files!.isNotEmpty) {
        if (event.dataTransfer.files![0].size <= 0) return;
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

  Future<Map<String, dynamic>?> getImportedFiles() async {
    if (lastUri != null) {
      Map<String, dynamic>? importedFiles =
          await Utils.parseFragment(Uri.decodeComponent(lastUri!));
      return importedFiles;
    }
  }

  Future<String> getString(String name, String defaultValue) async {
    return html.window.localStorage[name] ?? defaultValue;
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
    if (!copyStatus) context.callMethod('prompt', ['', text]);
    return copyStatus;
  }

  Future<UploadgramFile?> askForFile([String? type]) {
    var completer = Completer<UploadgramFile?>();
    html.FileUploadInputElement inputFile = html.FileUploadInputElement();
    if (type != null) inputFile.accept = type;
    html.document.body!.append(inputFile);
    inputFile.click();
    inputFile.onChange.listen((_) {
      if (inputFile.files!.isEmpty) return;
      html.File? file = inputFile.files![0];
      inputFile.remove();
      completer.complete(
          UploadgramFile(realFile: file, size: file.size, name: file.name));
    });
    inputFile.onAbort.listen((_) => completer.complete(null));
    return completer.future;
  }

  bool isWebAndroid() => html.window.navigator.userAgent.contains('Android');

  Future<Map?> importFiles() async {
    UploadgramFile? uploadgramFile = await askForFile();
    if (uploadgramFile == null) return null;
    html.File file = uploadgramFile.realFile as html.File;
    html.FileReader reader = html.FileReader();
    reader.readAsText(file);
    await Future.any([reader.onLoad.first, reader.onError.first]);
    String? result = reader.result as String?;
    if (result == null) return null;
    Map? files = json.decode(result);
    return files is Map ? files : null;
  }

  Future<void> clearFilesCache() async {}
  Future<void> deleteCachedFile(String name) async {}

  Future<bool?> saveFile(String filename, String content) async {
    html.Blob blob = html.Blob([content]);
    html.AnchorElement a = html.AnchorElement();
    String url = a.href = html.Url.createObjectUrlFromBlob(blob);
    a.setAttribute('download', filename);
    html.document.body!.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  }

  Future<void> deletePreferences() async => html.window.localStorage.clear();

  Future<Color> getAccent() =>
      throw UnsupportedError('getAccent() has not been implemented.');
}
