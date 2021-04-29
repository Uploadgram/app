import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';

class AppLogic {
  static late UploadedFiles files = UploadedFiles();
  static InternalAPIWrapper platformApi = InternalAPIWrapper();
  static WebAPIWrapper webApi = WebAPIWrapper();

  static List<String> selected = [];
  static List<UploadingFile> uploadingQueue = [];

  static Future<void> getFiles() => files.init();

  static Future<bool> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text)).then((value) => true);

  static Stream<UploadingEvent>? uploadFileStream(UploadingFile file) {
    if (file.locked == true) return null;
    file.locked = true;
    var controller = StreamController<UploadingEvent>.broadcast();
    () async {
      // this while loop could be probably improved or removed
      while (uploadingQueue[0].fileKey != file.fileKey) {
        await Future.delayed(Duration(milliseconds: 500));
      }
      var result = await webApi.uploadFile(
        file.uploadgramFile,
        onProgress: (double progress, int bytesPerSec, String remaining) {
          controller.add(UploadingEventProgress(
              progress: progress, bytesPerSec: bytesPerSec));
        },
      );
      if (result.ok) {
        var fileObj = UploadedFile(
          name: file.uploadgramFile.name,
          size: file.uploadgramFile.size,
          url: result.url!,
          delete: result.delete!,
        );
        files[result.delete!] = fileObj;
        controller
            .add(UploadingEventEnd(delete: result.delete!, file: fileObj));
      } else {
        String _error = 'An error occurred while obtaining the response';
        if (result.statusCode > 500)
          _error = 'We are having server problems. Try again later.';
        if (result.errorMessage != null) _error = result.errorMessage!;
        controller.addError(_error);
      }
      controller.close();
      if (!canGenerateThumbnail(uploadingQueue[0].uploadgramFile.size,
          uploadingQueue[0].uploadgramFile.name)) {
        await AppLogic.platformApi
            .deleteCachedFile(uploadingQueue[0].uploadgramFile.name);
      }
      uploadingQueue.removeAt(0);
    }();
    return controller.stream;
  }

  static void showFullscreenLoader(BuildContext context) {
    Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WillPopScope(
              child: Center(child: CircularProgressIndicator()),
              onWillPop: () async => false),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(opacity: animation, child: child),
          opaque: false,
          barrierDismissible: false,
          barrierColor: Colors.black.withOpacity(0.75),
        ));
  }
}

class UploadedFiles {
  bool isInitialised = false;
  late LazyBox _filesBox;
  late LazyBox _filesOrderBox;

  Future<void> init() async {
    if (!await Hive.boxExists('files')) {
      _filesBox = await Hive.openLazyBox('files');
      await _maybeMigrate();
    } else
      _filesBox = await Hive.openLazyBox('files');
    _filesOrderBox = await Hive.openLazyBox('filesOrder');
    isInitialised = true;
  }

  Future<void> _maybeMigrate() async {
    var oldFiles = await AppLogic.platformApi.getString('uploaded_files', '{}');
    if (oldFiles == null || oldFiles == '{}') return;
    var maybeDecoded = json.decode(oldFiles);
    if (maybeDecoded == null) return;
    await addAll(maybeDecoded);
    await AppLogic.platformApi.deletePreferences();
  }

  /// this should run in another thread, as this is potentially blocking
  Future<bool> sort(SortOptions sortOptions) {
    switch (sortOptions.sortBy) {
      case SortBy.name:
        return _bubbleSort(sortOptions.sortType == SortType.ascending
            ? (entry, nextEntry) =>
                (entry['filename'] as String)
                    .compareTo(nextEntry['filename'] as String) >
                0
            : (entry, nextEntry) =>
                (entry['filename'] as String)
                    .compareTo(nextEntry['filename'] as String) <=
                0);
      case SortBy.size:
        return _bubbleSort(sortOptions.sortType == SortType.ascending
            ? (entry, nextEntry) =>
                (entry['size'] as int) > (nextEntry['size'] as int)
            : (entry, nextEntry) =>
                (entry['size'] as int) <= (nextEntry['size'] as int));
      case SortBy.upload_date:
        return _bubbleSort(sortOptions.sortType == SortType.ascending
            ? (entry, nextEntry) =>
                Utils.getUploadedDate(entry['url']) >
                Utils.getUploadedDate(nextEntry['url'])
            : (entry, nextEntry) =>
                Utils.getUploadedDate(entry['url']) <=
                Utils.getUploadedDate(nextEntry['url']));
    }
  }

  Future<bool> _bubbleSort(
      bool Function(Map entry, Map nextEntry) compare) async {
    int len = _filesOrderBox.length;
    bool didOrder = false;
    bool hasOrderedOnce = false;
    // simple bubblesort implementation
    for (int i = 0; i < len - 1; i++) {
      for (int j = 0; j < len - i - 1; j++) {
        String? delete = await _filesOrderBox.getAt(j);
        String? nextDelete = await _filesOrderBox.getAt(j + 1);
        if (delete == null || nextDelete == null) continue;
        Map entry = await _filesBox.get(delete);
        Map nextEntry = await _filesBox.get(nextDelete);
        bool shouldSwap = compare.call(entry, nextEntry);
        if (shouldSwap) {
          print('swapping $delete and $nextDelete');
          await _filesOrderBox.putAt(j, nextDelete);
          await _filesOrderBox.putAt(j + 1, delete);
          didOrder = true;
          hasOrderedOnce = true;
        }
      }
      if (didOrder == false) break;
      didOrder = false;
    }
    return hasOrderedOnce;
  }

  Future<void> addAll(Map files) async {
    await Future.wait([
      _filesBox.putAll(files),
      _filesOrderBox.addAll(files.keys as Iterable<String>),
    ]);
  }

  Future<void> remove(String fileId) async {
    for (int i = 0; i < _filesOrderBox.length; i++) {
      // this is needed because it seems like .delete doesn't delete if you pass in a value, it looks for the key
      if (await _filesOrderBox.getAt(i) == fileId) _filesOrderBox.deleteAt(i);
    }
    await _filesBox.delete(fileId);
  }

  Future<void> removeAt(int index) async => await Future.wait([
        _filesBox.delete(await _filesOrderBox.getAt(index)),
        _filesOrderBox.deleteAt(index)
      ]);

  int get length => _filesBox.length;
  Iterable<dynamic> get keys => _filesBox.keys;
  bool get isEmpty => _filesBox.isEmpty;

  Future<UploadedFile?> operator [](String fileId) async =>
      UploadedFile.fromJson(await _filesBox.get(fileId), fileId,
          onChanged: (UploadedFile newValue) => this[fileId] = newValue);
  Future<UploadedFile?> elementAt(int index) async {
    String? fileId = await _filesOrderBox.getAt(index);
    if (fileId == null) throw IndexError(index, this);
    return await this[fileId];
  }

  operator []=(String fileId, UploadedFile file) async {
    await Future.wait([
      _filesBox.put(fileId, file.toJson()),
      _filesOrderBox.add(fileId),
    ]);
  }
}

class UploadedFile {
  String _name;
  int _size;
  String _url;
  final String? delete;
  final Function(UploadedFile)? _onChanged;

  UploadedFile({
    required name,
    required size,
    required url,
    required this.delete,
    onChanged,
  })  : _name = name,
        _size = size,
        _url = url,
        _onChanged = onChanged;
  factory UploadedFile.fromJson(Map json, String delete,
          {Function(UploadedFile)? onChanged}) =>
      UploadedFile(
          name: json['filename'] as String,
          size: json['size'] as int,
          url: json['url'] as String,
          delete: delete,
          onChanged: onChanged);

  UploadedFile copyWith(
          {String? name,
          int? size,
          String? url,
          Function(UploadedFile)? onChanged}) =>
      UploadedFile(
        name: name ?? this._name,
        size: size ?? this._size,
        url: url ?? this._url,
        onChanged: onChanged ?? this._onChanged,
        delete: this.delete,
      );

  Map toJson() => {'filename': _name, 'size': _size, 'url': _url};

  String toString() => json.encode(this);

  int get hashCode => hashValues(_name, _size, _url);

  bool operator ==(Object other) =>
      other is UploadedFile &&
      _name == other._name &&
      _size == other._size &&
      _url == other._url;

  String get name => _name;
  set name(String newValue) {
    _name = newValue;
    _onChanged?.call(this);
  }

  int get size => _size;
  set size(int value) {
    _size = value;
    _onChanged?.call(this);
  }

  String get url => _url;
  set url(String value) {
    _url = value;
    _onChanged?.call(this);
  }
}
