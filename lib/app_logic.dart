import 'dart:ui';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';

class AppLogic {
  static final ValueNotifier<Locale?> currentLocale = ValueNotifier(null);
  static late final ValueNotifier<Color> currentAccent =
      ValueNotifier(Settings.themeAccent);

  static Future<void> getFiles() async {
    await UploadedFiles().init();
    final importedFiles = await InternalAPIWrapper().getImportedFiles();
    if (importedFiles != null) await UploadedFiles().addAll(importedFiles);
  }

  static Future<bool> copy(String text) =>
      Clipboard.setData(ClipboardData(text: text)).then((value) => true);

  static List<UploadingFile> get queue => WebAPIWrapper().queue;

  static Future<void> updateAccent() => Settings.updateAccent()
      .then((value) => currentAccent.value = Settings.themeAccent);

  static Future<void> setAccent(Color? accent) async {
    if (accent == null) {
      settings.syncAccentWithSystem = true;
      return await updateAccent();
    }
    settings.accent = accent;

    currentAccent.value = Settings.themeAccent;
    if (settings.syncAccentWithSystem == true) {
      settings.syncAccentWithSystem = false;
      return await updateAccent();
    }
  }

  static void showFullscreenLoader(BuildContext context,
      [ValueNotifier<double?>? progressNotifier]) {
    Navigator.push(
        context,
        progressNotifier == null
            ? PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    WillPopScope(
                        child: const Center(child: CircularProgressIndicator()),
                        onWillPop: () async => false))
            : PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  double prevValue = 0.0;
                  return WillPopScope(
                      child: Material(
                          color: Colors.transparent,
                          child: ValueListenableBuilder<double?>(
                              builder: (context, value, _) => Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                            child: value == null
                                                ? const CircularProgressIndicator(
                                                    strokeWidth: 6.0)
                                                : TweenAnimationBuilder<
                                                        double?>(
                                                    tween: Tween(
                                                        begin: prevValue,
                                                        end: prevValue = value),
                                                    duration: const Duration(
                                                        milliseconds: 125),
                                                    curve: Curves.ease,
                                                    builder: (context,
                                                            animation, _) =>
                                                        CircularProgressIndicator(
                                                            strokeWidth: 6.0,
                                                            value: animation)),
                                            width: 75,
                                            height: 75),
                                        const SizedBox(height: 25.0),
                                        Text(
                                            AppLocalizations.of(context)
                                                .operationCompleting(
                                                    ((value ?? 0) * 100)
                                                        .toStringAsFixed(0)),
                                            style: const TextStyle(
                                                fontSize: 17.0)),
                                      ]),
                              valueListenable: progressNotifier)),
                      onWillPop: () async => false);
                },
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child),
                opaque: false,
                barrierDismissible: false,
                barrierColor: Colors.black.withOpacity(0.75),
              ));
  }
}

class UploadedFiles {
  /// The only instance of this class.
  ///
  /// Returned when calling [UploadedFiles]'s main constructor
  static final instance = UploadedFiles._();

  /// Singleton constructor, it's the same as using [UploadedFiles.instance]
  factory UploadedFiles() => instance;

  UploadedFiles._();

  bool _isInitialised = false;
  get isInitialized => _isInitialised;
  late LazyBox _filesBox;
  late LazyBox _filesOrderBox;

  static final _logger = Logger('UploadedFiles');

  Future<void> init() async {
    if (_isInitialised) return;
    _logger.info('initializing...');
    bool didBoxExist = await Hive.boxExists('files');
    _filesBox = await Hive.openLazyBox('files');
    if (!didBoxExist) await _maybeMigrate();
    _filesOrderBox = await Hive.openLazyBox('filesOrder');
    _isInitialised = true;
  }

  Future<void> _maybeMigrate() async {
    _logger.info('importing files from older format...');
    var oldFiles = await InternalAPIWrapper().getString('uploaded_files', '{}');
    _logger.fine('importing "$oldFiles"');
    if (oldFiles == null || oldFiles == '{}') return;
    Map<String, dynamic>? maybeDecoded =
        (json.decode(oldFiles) as Map?)?.cast<String, dynamic>();
    if (maybeDecoded == null) return;
    await addAll(maybeDecoded);
    await InternalAPIWrapper().deletePreferences();
  }

  /// Calls the sorting function with the correct sorting options
  Future<bool> sort(SortOptions sortOptions) {
    switch (sortOptions.sortBy) {
      case SortBy.name:
        return _sort(sortOptions.sortType == SortType.descending
            ? (entry, nextEntry) =>
                (entry['filename'] as String)
                    .compareTo(nextEntry['filename'] as String) >
                0
            : (entry, nextEntry) =>
                (entry['filename'] as String)
                    .compareTo(nextEntry['filename'] as String) <=
                0);
      case SortBy.size:
        return _sort(sortOptions.sortType == SortType.descending
            ? (entry, nextEntry) =>
                (entry['size'] as int) > (nextEntry['size'] as int)
            : (entry, nextEntry) =>
                (entry['size'] as int) <= (nextEntry['size'] as int));
      case SortBy.uploadDate:
        return _sort(sortOptions.sortType == SortType.descending
            ? (entry, nextEntry) =>
                Utils.getUploadedDate(entry['url']) >
                Utils.getUploadedDate(nextEntry['url'])
            : (entry, nextEntry) =>
                Utils.getUploadedDate(entry['url']) <=
                Utils.getUploadedDate(nextEntry['url']));
    }
  }

  /// Uses a bubble sort implementation to sort the files list.
  /// A manual implementation is used because [_filesBox] is a [LazyBox],
  /// and the for loop accesses each value without allocating them all in memory.
  ///
  /// This behaviour will definitely be improved in the future.
  Future<bool> _sort(bool Function(Map entry, Map nextEntry) compare) async {
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
          _logger.finest('swapping $delete and $nextDelete');
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

  Future<void> addAll(Map<String, dynamic> files) => Future.wait([
        _filesBox.putAll(files),
        _filesOrderBox.addAll(files.keys.cast<String>()),
      ]);

  Future<void> remove(String fileId) async {
    for (final key in _filesOrderBox.keys) {
      // look up for the key containing the value [fileId] and delete it out
      if (await _filesOrderBox.get(key) == fileId) {
        await _filesOrderBox.delete(key);
        break;
      }
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
  ValueListenable<void> get listenable => _filesBox.listenable();

  Future<Map<String, UploadedFile>> toJson() =>
      Future.wait<MapEntry<String, UploadedFile>>(_filesBox.keys
              .map<Future<MapEntry<String, UploadedFile>>>(
                  (e) => this[e].then((value) => MapEntry(e, value!))))
          .then((value) => Map.fromEntries(value));

  Future<UploadedFile?> operator [](String fileId) async =>
      UploadedFile.fromJson(await _filesBox.get(fileId), fileId,
          onChanged: (UploadedFile newValue) => add(newValue));

  Future<UploadedFile?> elementAt(int index) async {
    String? fileId = await _filesOrderBox.getAt(index);
    if (fileId == null) throw IndexError(index, this);
    return await this[fileId];
  }

  Future<void> add(UploadedFile file) =>
      _add(file, filesBox: _filesBox, filesOrderBox: _filesOrderBox);

  static Future<void> _add(UploadedFile file,
          {required LazyBox filesBox, required LazyBox filesOrderBox}) =>
      Future.wait([
        filesBox.put(file.delete, file.toJson()),
        filesOrderBox.add(file.delete),
      ]);

  static Future<void> addFile(UploadedFile file) async {
    final filesBox = await Hive.openLazyBox('files');
    final filesOrderBox = await Hive.openLazyBox('filesOrder');
    await _add(file, filesBox: filesBox, filesOrderBox: filesOrderBox);
    await Future.wait([
      filesBox.close(),
      filesOrderBox.close(),
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
          String? delete,
          Function(UploadedFile)? onChanged}) =>
      UploadedFile(
        name: name ?? _name,
        size: size ?? _size,
        url: url ?? _url,
        onChanged: onChanged ?? _onChanged,
        delete: delete ?? this.delete,
      );

  Map toJson() => {'filename': _name, 'size': _size, 'url': _url};

  @override
  String toString() => json.encode(this);

  @override
  int get hashCode => hashValues(_name, _size, _url);

  @override
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
