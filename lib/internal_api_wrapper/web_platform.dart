// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../utils.dart';

class InternalAPIWrapper {
  static String? lastUri;

  InternalAPIWrapper() {
    html.document.onContextMenu.listen((event) =>
        event.preventDefault()); // disable normal browser right click
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
    html.Range range = html.document.createRange();
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

  Future<Map?> askForFile([String? type]) {
    var completer = Completer<Map>();
    html.FileUploadInputElement inputFile = html.FileUploadInputElement();
    if (type != null) inputFile.accept = type;
    html.document.body!.append(inputFile);
    inputFile.click();
    inputFile.onChange.listen((_) {
      if (inputFile.files!.length == 0) return null;
      html.File? file = inputFile.files![0];
      inputFile.remove();
      completer
          .complete({'realFile': file, 'size': file.size, 'name': file.name});
    });
    inputFile.onAbort.listen((_) => completer.complete(null));
    return completer.future;
  }

  bool isWebAndroid() => html.window.navigator.userAgent.contains('Android');

  Future<Map?> importFiles() async {
    Map? fileMap = await askForFile();
    if (fileMap == null) return null;
    html.File file = fileMap['realFile'];
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
    html.LinkElement a = html.LinkElement();
    String url = a.href = html.Url.createObjectUrlFromBlob(blob);
    a.setAttribute('download', filename);
    html.document.body!.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
    return true;
  }
}
