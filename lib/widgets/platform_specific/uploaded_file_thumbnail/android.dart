import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';

int _howManyImagesAreDownloading = 0;

class _ThumbnailGeneratorData implements ThumbnailGeneratorData {
  final String? url;
  final _ThumbnailData thumbnailsData;
  final File? file;
  final SendPort sendPort;
  final int finalImageSize;
  final String fileId;

  _ThumbnailGeneratorData({
    required this.sendPort,
    required this.thumbnailsData,
    required this.fileId,
    this.finalImageSize = 200,
    this.url,
    this.file,
  }) : assert(url != null || file != null);
}

class _ThumbnailData implements ThumbnailData {
  final File? thumbSmall;
  final File? thumbFull;
  _ThumbnailData({
    required this.thumbSmall,
    this.thumbFull,
  });
}

class _ThumbnailsMemoryCache {
  static HashMap _cache = HashMap();

  static HashMap _locks = HashMap();

  static bool acquireLock(String fileId) {
    if (_locks[fileId] != null) return false;
    return _locks[fileId] = true;
  }

  static void releaseLock(String fileId) => _locks.remove(fileId);

  static void add(String fileId, File thumbSmall, [File? thumbFull]) {
    print('add called for $fileId');
    _cache[fileId] =
        _ThumbnailData(thumbSmall: thumbSmall, thumbFull: thumbFull);
  }

  static void clear() => _cache.clear();

  static _ThumbnailData? get(String fileId) {
    return _cache[fileId];
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
    final Directory appDocs = await getApplicationSupportDirectory();
    final Directory imageCache =
        Directory('${appDocs.path}${Platform.pathSeparator}thumbs');
    await File('${imageCache.path}${Platform.pathSeparator}$fileId').delete();
    final Directory fullImagesCache =
        Directory('${appDocs.path}${Platform.pathSeparator}thumbs-full');
    final imageFull =
        File('${fullImagesCache.path}${Platform.pathSeparator}$fileId');
    if (await imageFull.exists()) await imageFull.delete();
  }

  static Future<void> deleteSmallThumbs() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    await Directory('${appDocs.path}/thumbs').delete(recursive: true);
    _ThumbnailsMemoryCache.clear();
  }

  static Future<void> deleteBigThumbs() async {
    final Directory appDocs = await getApplicationSupportDirectory();
    await Directory('${appDocs.path}/thumbs-full').delete(recursive: true);
    _ThumbnailsMemoryCache.clear();
  }

  static bool isFullThumbAvailable(String fileId) =>
      _ThumbnailsMemoryCache.get(fileId) != null;
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
  final bool imageInsteadOfContainer;

  UploadedFileThumbnail({
    required this.uploadedFile,
    required this.defaultIcon,
    this.defaultIconSize,
    this.defaultIconColor,
    this.fullImageSize = false,
    this.file,
    this.heroTag,
    this.borderRadius,
    this.forceDownloadImage = false,
    this.imageInsteadOfContainer = false,
  });

  static Future<void> _generateImages(_ThumbnailGeneratorData data) async {
    List<int> imageBytes;
    if (data.file == null) {
      print('Downloading image...');
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
      print('Generating thumbs from local file...');
      data.sendPort.send(null);
      imageBytes = data.file!.readAsBytesSync();
      AppLogic.platformApi
          .deleteCachedFile(data.file!.path.split(Platform.pathSeparator).last);
    }
    var finalImage;
    if (!data.thumbnailsData.thumbSmall!.existsSync()) {
      finalImage = await generateThumbnail(imageBytes, data.finalImageSize);
      if (finalImage == null) {
        data.sendPort.send(false);
        return;
      }
    }
    Future.wait([
      if (data.thumbnailsData.thumbSmall != null && finalImage != null)
        data.thumbnailsData.thumbSmall!.writeAsBytes(finalImage),
      if (data.thumbnailsData.thumbFull != null &&
          !data.thumbnailsData.thumbFull!.existsSync())
        data.thumbnailsData.thumbFull!.writeAsBytes(imageBytes),
    ]).then((value) => data.sendPort.send(true));
  }

  Future<_ThumbnailData?> _generateThumbs(
      UploadedFile uploadedFile, File? file) async {
    if (!canGenerateThumbnail(uploadedFile.size, uploadedFile.name))
      return null;
    if (file != null && await file.length() > 5000000) return null;

    final Directory appDocs = await getApplicationSupportDirectory();
    final Directory imageCache =
        await Directory('${appDocs.path}${Platform.pathSeparator}thumbs')
            .create(); // create if it does not exist
    final Directory fullImagesCache =
        await Directory('${appDocs.path}${Platform.pathSeparator}thumbs-full')
            .create(); // create if it does not exist
    final File image200 = File(
        '${imageCache.path}${Platform.pathSeparator}${uploadedFile.delete!}');
    final File imageFull = File(
        '${fullImagesCache.path}${Platform.pathSeparator}${uploadedFile.delete!}');
    if (!_ThumbnailsMemoryCache.acquireLock(uploadedFile.delete!)) {
      while (!_ThumbnailsMemoryCache.acquireLock(uploadedFile.delete!))
        await Future.delayed(Duration(milliseconds: 500));
      _ThumbnailsMemoryCache.releaseLock(uploadedFile.delete!);
      return _ThumbnailData(
          thumbSmall: image200,
          thumbFull: await imageFull.exists() ? imageFull : null);
    }

    final ReceivePort receivePort = ReceivePort();
    final _ThumbnailData _thumbnailsData = _ThumbnailData(
      thumbSmall: image200,
      thumbFull: await imageFull.exists() ||
              AppSettings.saveFullSizedImages ||
              forceDownloadImage
          ? imageFull
          : null,
    );
    if (!await image200.exists() ||
        (!await imageFull.exists() && forceDownloadImage)) {
      while (_howManyImagesAreDownloading > 0)
        await Future.delayed(Duration(milliseconds: 500));
      //why do i come up with these dumb ideas?
      _howManyImagesAreDownloading++;
      await Isolate.spawn(
          _generateImages,
          _ThumbnailGeneratorData(
              sendPort: receivePort.sendPort,
              thumbnailsData: _thumbnailsData,
              finalImageSize: AppSettings.smallThumbnailSize,
              url: uploadedFile.url,
              file: file,
              fileId: uploadedFile.delete!));
      final Completer completer = Completer<bool>();
      receivePort.listen((message) {
        if (message == null)
          _howManyImagesAreDownloading--;
        else
          completer.complete(message);
      });
      if (!await completer.future) {
        _ThumbnailsMemoryCache.releaseLock(uploadedFile.delete!);
        throw ErrorDescription('Couldn\'t generate thumbnails');
      }
    }

    _ThumbnailsMemoryCache.releaseLock(uploadedFile.delete!);
    _ThumbnailsMemoryCache.add(uploadedFile.delete!, image200,
        await imageFull.exists() ? imageFull : null);
    return _thumbnailsData;
  }

  @override
  Widget build(BuildContext context) {
    final Widget fallback = Center(
        child: Icon(
      defaultIcon,
      size: defaultIconSize,
      color: defaultIconColor,
    ));
    getImage(File thumbSmall, File? thumbFull) {
      final image = imageInsteadOfContainer
          ? Image.file(
              fullImageSize && thumbFull != null ? thumbFull : thumbSmall)
          : Container(
              decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(fullImageSize && thumbFull != null
                          ? thumbFull
                          : thumbSmall))));
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

    if (_ThumbnailsMemoryCache.get(uploadedFile.delete!) != null &&
        !(forceDownloadImage &&
            _ThumbnailsMemoryCache.get(uploadedFile.delete!)?.thumbFull ==
                null)) {
      print('cached thumbs!');
      final thumbs = _ThumbnailsMemoryCache.get(uploadedFile.delete!);
      return getImage(thumbs!.thumbSmall!, thumbs.thumbFull);
    }
    return canGenerateThumbnail(uploadedFile.size, uploadedFile.name)
        ? Container(
            child: FutureBuilder<_ThumbnailData?>(
                builder: (BuildContext context,
                    AsyncSnapshot<_ThumbnailData?> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasData && snapshot.data != null) {
                      return getImage(
                          snapshot.data!.thumbSmall!, snapshot.data!.thumbFull);
                    }
                    if (snapshot.hasError || snapshot.data == null)
                      return fallback;
                  }
                  return Center(child: CircularProgressIndicator());
                },
                future: _generateThumbs(uploadedFile, file)))
        : heroTag == null
            ? fallback
            : Hero(tag: heroTag!, child: fallback);
  }
}
