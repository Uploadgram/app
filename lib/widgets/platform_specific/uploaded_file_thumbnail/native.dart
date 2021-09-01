import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:tuple/tuple.dart';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:synchronized/synchronized.dart' as synchronized;

import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/internal_api_wrapper/native_platform.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';

Future<Directory> getThumbnailsCache() => getApplicationSupportDirectory().then(
    (dir) => Directory('${dir.path}${Platform.pathSeparator}thumbs').create());
Future<Directory> getFullThumbnailsCache() =>
    getApplicationSupportDirectory().then((dir) =>
        Directory('${dir.path}${Platform.pathSeparator}thumbs-full').create());
Future<File> getThumbnailFor(String fileId) => getThumbnailsCache()
    .then((dir) => File('${dir.path}${Platform.pathSeparator}$fileId'));
Future<File> getFullThumbnailFor(String fileId) => getFullThumbnailsCache()
    .then((dir) => File('${dir.path}${Platform.pathSeparator}$fileId'));

class _ThumbnailGeneratorData implements ThumbnailGeneratorData {
  @override
  final String? url;
  @override
  final ThumbnailData thumbnailsData;
  @override
  final File? file;
  final SendPort sendPort;
  @override
  final int finalImageSize;
  final String fileId;
  final String cacheDir;

  _ThumbnailGeneratorData({
    required this.sendPort,
    required this.thumbnailsData,
    required this.fileId,
    required this.cacheDir,
    this.finalImageSize = 200,
    this.url,
    this.file,
  }) : assert(url != null || file != null);
}

class ThumbnailData implements ThumbnailDataImpl {
  @override
  final File? thumbSmall;
  @override
  final File? thumbFull;
  ThumbnailData({
    required this.thumbSmall,
    this.thumbFull,
  });

  List<String?> toJson() => <String?>[thumbSmall?.path, thumbFull?.path];

  ThumbnailData.fromJson(List<String?> json)
      : thumbSmall = json[0] == null ? null : File(json[0]!),
        thumbFull = json[1] == null ? null : File(json[1]!);

  bool isNull() => thumbSmall == null && thumbFull == null;
}

class ThumbnailDataAdapter extends TypeAdapter<ThumbnailData> {
  @override
  int get typeId => 6;
  @override
  void write(BinaryWriter writer, ThumbnailData obj) {
    writer.writeList(obj.toJson());
  }

  @override
  ThumbnailData read(BinaryReader reader) {
    List<String?> values = reader.readList().cast<String?>();
    return ThumbnailData.fromJson(values);
  }
}

class ThumbnailsUtils {
  static Future<ThumbnailsStats> getThumbnailsStats() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    final Directory smallThumbsCache =
        await Directory('${appDocs.path}/thumbs').create();
    final Directory bigThumbsCache =
        await Directory('${appDocs.path}/thumbs-full').create();
    int smallThumbsSize = 0;
    int smallThumbsCount = 0;
    int bigThumbsSize = 0;
    int bigThumbsCount = 0;
    await for (FileSystemEntity file in smallThumbsCache.list()) {
      if (file is File) {
        smallThumbsSize += await file.length();
        smallThumbsCount++;
      }
    }
    await for (FileSystemEntity file in bigThumbsCache.list()) {
      if (file is File) {
        bigThumbsSize += await file.length();
        bigThumbsCount++;
      }
    }
    return ThumbnailsStats(
      smallThumbsCount: smallThumbsCount,
      smallThumbsSize: smallThumbsSize,
      bigThumbsCount: bigThumbsCount,
      bigThumbsSize: bigThumbsSize,
    );
  }

  static Future<void> deleteThumbsForFile(String fileId) async {
    final image = await getThumbnailFor(fileId);
    if (await image.exists()) await image.delete();
    final imageFull = await getFullThumbnailFor(fileId);
    if (await imageFull.exists()) await imageFull.delete();
    await ThumbnailsMemoryCache.remove(fileId);
  }

  static Future<void> deleteSmallThumbs() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    await Directory('${appDocs.path}/thumbs').delete(recursive: true);
    for (final key in ThumbnailsMemoryCache.keys) {
      final entry = ThumbnailsMemoryCache.get(key)!;
      if (entry.thumbFull == null) {
        await ThumbnailsMemoryCache.delete(key);
      } else {
        await ThumbnailsMemoryCache.add(
            key, ThumbnailData(thumbSmall: null, thumbFull: entry.thumbFull!));
      }
    }
  }

  static Future<void> deleteBigThumbs() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    await Directory('${appDocs.path}/thumbs-full').delete(recursive: true);
    for (final key in ThumbnailsMemoryCache.keys) {
      final entry = ThumbnailsMemoryCache.get(key)!;
      if (entry.thumbSmall == null) {
        await ThumbnailsMemoryCache.delete(key);
      } else {
        await ThumbnailsMemoryCache.add(
            key, ThumbnailData(thumbSmall: entry.thumbSmall));
      }
    }
  }

  static Future<void> deleteAllThumbs() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    await Directory('${appDocs.path}/thumbs').delete(recursive: true);
    await Directory('${appDocs.path}/thumbs-full').delete(recursive: true);
    await ThumbnailsMemoryCache.clear();
  }

  static bool isFullThumbAvailable(String fileId) {
    final entry = ThumbnailsMemoryCache.get(fileId);
    return entry?.thumbFull != null;
  }
}

class UploadedFileThumbnail extends StatelessWidget {
  final UploadedFile uploadedFile;
  final bool fullImageSize;
  final IconData defaultIcon;
  final double? defaultIconSize;
  final Color? defaultIconColor;
  final File? file;
  final Object? heroTag;
  final BorderRadius? borderRadius;
  final bool forceDownloadImage;
  final bool fullscreenImage;

  const UploadedFileThumbnail({
    Key? key,
    required this.uploadedFile,
    required this.defaultIcon,
    this.defaultIconSize,
    this.defaultIconColor,
    this.fullImageSize = false,
    Object? file,
    this.heroTag,
    this.borderRadius,
    this.forceDownloadImage = false,
    this.fullscreenImage = false,
  })  : file = file as File?,
        super(key: key);

  static final downloadingLock = synchronized.Lock();

  static Future<void> _generateImages(_ThumbnailGeneratorData data) async {
    await InternalAPIWrapper().setupLoggerIsolate();
    final _logger = Logger('UploadedFileThumbnail Isolate');
    List<int> imageBytes;
    if (data.file == null &&
        (data.thumbnailsData.thumbFull == null ||
            !data.thumbnailsData.thumbFull!.existsSync())) {
      _logger.info('Downloading image...');
      try {
        var response = await Dio().get('${data.url!}?raw',
            options: Options(responseType: ResponseType.bytes));
        data.sendPort.send(null);
        if (response.statusCode! != 200) {
          data.sendPort.send(false);
          return;
        }
        imageBytes = response.data as List<int>;
      } on DioError {
        data.sendPort.send(null);
        data.sendPort.send(false);
        return;
      }
    } else {
      _logger.info('Generating thumbs from local file...');
      data.sendPort.send(null);
      final file = (data.file ?? data.thumbnailsData.thumbFull)!;
      imageBytes = file.readAsBytesSync();

      if (data.file != null && data.file!.parent.parent.path == data.cacheDir) {
        data.file!.deleteSync();
      } // delete if the file is cached
    }
    List<int>? finalImage;
    if (!data.thumbnailsData.thumbSmall!.existsSync()) {
      finalImage = await generateThumbnail(imageBytes, data.finalImageSize);
      if (finalImage == null) {
        data.sendPort.send(false);
        return;
      }
    }
    Future.wait([
      if (data.thumbnailsData.thumbSmall != null &&
          finalImage != null &&
          !data.thumbnailsData.thumbSmall!.existsSync())
        data.thumbnailsData.thumbSmall!.writeAsBytes(finalImage),
      if (data.thumbnailsData.thumbFull != null)
        data.thumbnailsData.thumbFull!.writeAsBytes(imageBytes),
    ]).then((value) => data.sendPort.send(true));
  }

  static Tuple2<Future<void>, Future<bool>> generateThumbnails({
    required ThumbnailData thumbnailData,
    required String cacheDir,
    required UploadedFile uploadedFile,
    required File? file,
  }) {
    final completer = Completer<bool>();
    final lockCompleter = Completer();
    () async {
      final receivePort = ReceivePort();
      await Isolate.spawn(
          _generateImages,
          _ThumbnailGeneratorData(
              sendPort: receivePort.sendPort,
              thumbnailsData: thumbnailData,
              finalImageSize: settings.smallThumbnailSize,
              url: uploadedFile.url,
              file: file,
              fileId: uploadedFile.delete!,
              cacheDir: cacheDir));
      receivePort.listen((message) {
        if (message == null) {
          lockCompleter.complete();
        } else {
          completer.complete(message);
        }
      });
    }();

    return Tuple2(lockCompleter.future, completer.future);
  }

  static Future<ThumbnailData> getThumbnailData(
      {required String delete}) async {
    final File image200 = await getThumbnailFor(delete);
    final File imageFull = await getFullThumbnailFor(delete);
    return ThumbnailData(
        thumbSmall: image200,
        thumbFull: await imageFull.exists() ? imageFull : null);
  }

  Future<ThumbnailData?> _generateThumbs(
      UploadedFile uploadedFile, File? file) async {
    if (!canGenerateThumbnail(uploadedFile.size, uploadedFile.name)) {
      return null;
    }
    if (file != null && await file.length() > 20000000) return null;

    synchronized.Lock? lock;
    if ((lock = ThumbnailsMemoryCache.getLock(uploadedFile.delete!)) != null) {
      return await lock!
          .synchronized(() => getThumbnailData(delete: uploadedFile.delete!));
    }
    lock = ThumbnailsMemoryCache.acquireLock(uploadedFile.delete!);

    final File image200 = await getThumbnailFor(uploadedFile.delete!);
    final File imageFull = await getFullThumbnailFor(uploadedFile.delete!);
    return await lock!.synchronized(() async {
      final ThumbnailData _thumbnailsData = ThumbnailData(
        thumbSmall: image200,
        thumbFull: await imageFull.exists() ||
                settings.saveFullSizedImages ||
                forceDownloadImage
            ? imageFull
            : null,
      );
      if (!await image200.exists() ||
          (!await imageFull.exists() && forceDownloadImage)) {
        final futures = generateThumbnails(
            thumbnailData: _thumbnailsData,
            cacheDir: await getTemporaryDirectory().then((value) => value.path),
            uploadedFile: uploadedFile,
            file: file);
        // the first item is the lock future and completes when the download has been completed
        // this is because uploadgram only allows one concurrent download per file.
        await downloadingLock.synchronized(() => futures.item1);
        await futures.item2;
      }

      ThumbnailsMemoryCache.releaseLock(uploadedFile.delete!);
      await ThumbnailsMemoryCache.add(
          uploadedFile.delete!,
          ThumbnailData(
              thumbSmall: image200,
              thumbFull: await imageFull.exists() ? imageFull : null));
      return _thumbnailsData;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback = Center(
        child: Icon(
      defaultIcon,
      size: defaultIconSize,
      color: defaultIconColor,
    ));
    if (heroTag != null) fallback = Hero(tag: heroTag!, child: fallback);

    if (uploadedFile.delete == null ||
        !canGenerateThumbnail(uploadedFile.size, uploadedFile.name)) {
      return fallback;
    }

    if (file != null) {
      // the file has just been uploaded, therefore we may schedule for thumbnail generation (now or later)
      ThumbnailsMemoryCache.schedule(uploadedFile.delete!);
    }

    if (ThumbnailsMemoryCache.get(uploadedFile.delete!) == null) {
      return fallback;
    }

    getImage(File? thumbSmall, File? thumbFull) {
      final image = Container(
          decoration: BoxDecoration(
              borderRadius: borderRadius,
              image: DecorationImage(
                  fit: fullscreenImage ? BoxFit.contain : BoxFit.cover,
                  image: FileImage(fullImageSize && thumbFull != null
                      ? thumbFull
                      : thumbSmall!))));
      final heroChild = fullImageSize && thumbFull == null
          ? ClipRect(
              child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                  child: image))
          : image;
      return heroTag == null
          ? heroChild
          : Hero(tag: heroTag!, child: heroChild);
    }

    final entry = ThumbnailsMemoryCache.get(uploadedFile.delete!);
    if (entry == null) return fallback;
    if ((entry.thumbSmall != null ||
            (fullImageSize && entry.thumbFull != null)) &&
        !(forceDownloadImage && entry.thumbFull == null)) {
      return getImage(entry.thumbSmall, entry.thumbFull);
    }

    return FutureBuilder<ThumbnailData?>(
        builder:
            (BuildContext context, AsyncSnapshot<ThumbnailData?> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData && snapshot.data != null) {
              return getImage(
                  snapshot.data!.thumbSmall!, snapshot.data!.thumbFull);
            }
            if (snapshot.hasError || snapshot.data == null) return fallback;
          }
          return Shimmer(child: Container());
        },
        future: _generateThumbs(uploadedFile, file));
  }
}

class ThumbnailsMemoryCache {
  ThumbnailsMemoryCache._();
  static late final Box<ThumbnailData> _cacheBox;

  static final HashMap<String, synchronized.Lock> _locks =
      HashMap<String, synchronized.Lock>();

  static synchronized.Lock? getLock(String fileId) {
    return _locks[fileId];
  }

  static synchronized.Lock? acquireLock(String fileId) {
    if (getLock(fileId) != null) return null;
    return _locks[fileId] = synchronized.Lock();
  }

  static void releaseLock(String fileId) => _locks.remove(fileId);

  static Future<void> init() {
    return Hive.openBox<ThumbnailData>('thumbnailCache')
        .then((value) => _cacheBox = value);
  }

  static Future<void> close() => _cacheBox.close();

  static Future<void> add(String id, ThumbnailData _data) =>
      _cacheBox.put(id, _data);

  static ThumbnailData? get(String id) => _cacheBox.get(id);

  static Future<void> delete(String id) => _cacheBox.delete(id);

  /// Schedule (an image) for thumbnail generation
  static Future<void> schedule(String id) =>
      add(id, ThumbnailData(thumbSmall: null));

  static Future<void> remove(String id) => _cacheBox.delete(id);

  static Future<void> clear() => _cacheBox.clear();

  static Iterable<String> get keys => _cacheBox.keys.cast<String>();
  static Iterable<ThumbnailData> get values => _cacheBox.values;
}
