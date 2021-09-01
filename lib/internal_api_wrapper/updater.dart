import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:duration/duration.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive_box_generator/hive_box_generator.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/internal_api_wrapper/native_platform.dart';
import 'package:uploadgram/utils.dart';

part 'updater.g.dart';

@HiveBox(boxName: 'updater')
abstract class _UpdaterCache {
  static final _instance = _$_UpdaterCacheInstance();

  @HiveBoxField()
  late DateTime? lastCheckedUpdate;
  @HiveBoxField()
  late _Release? asset;
  @HiveBoxField()
  late int? ignoreUpdate;
  @HiveBoxField()
  late int? updateId;
  @HiveBoxField()
  late String? changelog;

  Future<void> init() async {}
  Future<void> close() async {}
}

final _updaterCache = _UpdaterCache._instance;

class Updater {
  // singleton constructor
  static final _instance = Updater._();
  factory Updater() => _instance;
  Updater._();

  static final _logger = Logger('Updater');
  static const _pubspecYamlUrl =
      'https://raw.githubusercontent.com/Pato05/uploadgram-app/master/pubspec.yaml';
  static const _githubBaseUrl =
      'https://api.github.com/repos/pato05/uploadgram-app';

  static const _updateCheckTimeout = Duration(hours: 4);

  final _dio = Dio(BaseOptions(responseType: ResponseType.plain));

  bool _isUpdateAvailable = false;
  bool _isCacheInitialized = false;
  List<String>? _deviceABIs;
  _Release? _asset;
  String? _changelog;
  int? _updateId;

  String? get changelog => _changelog;
  int? get updateId => _updateId;

  bool _canCheckUpdates() {
    return _updaterCache.lastCheckedUpdate == null ||
        _updaterCache.lastCheckedUpdate!.difference(DateTime.now()) >
            _updateCheckTimeout;
  }

  Future<List<String>?> getDeviceABIs() => InternalAPIWrapper()
      .getDeviceAbiList()
      .then((value) => _deviceABIs = value);

  _Release? chooseAppropriateAsset(List<Map> assets) {
    int? apkFallbackId;
    int? sha256FallbackId;
    bool isSha256File(String assetName) =>
        assetName.startsWith('sha256-') && extension(assetName, 2) == 'apk.txt';
    bool isApkFile(String assetName) => extension(assetName) == 'apk';
    void getFallback(Map asset) {
      final assetName = asset['name'] as String;
      if ((sha256FallbackId == null || apkFallbackId == null) &&
          assetName.contains('app-release')) {
        if (isSha256File(assetName)) {
          _logger.info('found fallback sha256 file $assetName');
          sha256FallbackId = asset['id'];
        } else if (isApkFile(assetName)) {
          _logger.info('found fallback apk file $assetName');
          apkFallbackId = asset['id'];
        }
      }
    }

    if (_deviceABIs == null) {
      for (final asset in assets) {
        getFallback(asset);
        if (apkFallbackId != null && sha256FallbackId != null) break;
      }
    } else {
      for (final abi in _deviceABIs!) {
        int? apkId;
        int? sha256Id;
        for (final asset in assets) {
          final assetName = asset['name'] as String;

          if (assetName.contains(abi)) {
            if (isSha256File(assetName)) {
              _logger.info('found sha256 file ${asset['name']}');
              sha256Id = asset['id'];
            } else if (isApkFile(assetName)) {
              _logger.info('chosen ${asset['name']}');
              apkId = asset['id'];
            }
          }
          if (apkId != null && sha256Id != null) break;
          getFallback(asset);
        }
        if (apkId != null && sha256Id != null) {
          return _Release(apkId: apkId, sha256Id: sha256Id);
        }
      }
    }

    if (apkFallbackId != null && sha256FallbackId != null) {
      return _Release(apkId: apkFallbackId!, sha256Id: sha256FallbackId!);
    }
  }

  Future<bool?> checkForUpdates({
    bool force = false,
    bool countIgnoredUpdates = false,
  }) async {
    if (!Platform.isAndroid) {
      _logger.severe('Not checking updates for non-android platform');
      return null;
    }
    if (!_isCacheInitialized) {
      _logger.info('opening hive cache database...');
      await _updaterCache.init();
      _isCacheInitialized = true;
    }
    if (!force && !_canCheckUpdates()) {
      _logger.info(
          'Not checking for updates, a check has been done less than ${prettyDuration(_updateCheckTimeout)} ago');
      return null;
    }
    _updaterCache.lastCheckedUpdate = DateTime.now();
    _logger.info('checking for updates...');
    final packageInfo = await PackageInfo.fromPlatform();
    _logger.fine('getting pubspec.yaml from github');

    final pubspecResponse = await _dio.get(_pubspecYamlUrl);
    final pubspec = pubspecResponse.data as String;
    final version =
        Utils.getTextInBetween(pubspec, 'version: ', '\n').split('+');

    _logger.finer('app version: ${packageInfo.buildNumber}\n'
        'remote version: ${version[1]}');
    int? appVer = int.tryParse(packageInfo.buildNumber);
    int? remoteVer = int.tryParse(version[1]);
    if (appVer == null || remoteVer == null) {
      _logger.severe('Updates check failed, could not parse integers\n'
          'appVer: $appVer, remoteVer: $remoteVer');
      return null;
    }
    if (appVer < remoteVer) {
      if (!countIgnoredUpdates && _updaterCache.ignoreUpdate == remoteVer) {
        return null;
      }
      _updateId = remoteVer;
      if (_updaterCache.updateId == remoteVer) {
        _logger.info('found everything in updates cache');
        _asset = _updaterCache.asset;
        _changelog = _updaterCache.changelog;
      } else {
        _logger.info('clearing cache box');
        _updaterCache.clear();
        _logger.fine('making sure the update is released');
        final resp = await _dio.get<Map>('$_githubBaseUrl/releases/latest',
            options: Options(
                responseType: ResponseType.json,
                headers: {'accept': 'application/vnd.github.v3+json'}));
        final respData = resp.data; // should be already decoded
        if (respData == null) throw Exception('response data is null');
        if ((respData['tag_name'] as String).trim() == 'v${version[0]}') {
          _logger.fine('getting device\'s abi list...');
          await getDeviceABIs();
          _logger.fine('device abi: ${_deviceABIs.toString()}');
          _logger.fine('looking for the most appropriate release in assets...');
          _asset =
              chooseAppropriateAsset((respData['assets'] as List).cast<Map>());
          if (_asset == null) {
            _logger
                .severe('could not get most appropriate apk between assets!');
            return null;
          }
          _changelog = (respData['body'] as String).trim();
          _logger.info('caching update');
          _updaterCache.updateId = remoteVer;
          _updaterCache.changelog = _changelog;
          _updaterCache.asset = _asset;
          _logger.shout('An update is available ($appVer < $remoteVer)!');
        }
      }
      _isUpdateAvailable = true;
      return true;
    }
    _logger.fine('No updates available');
    return false;
  }

  bool get isUpdateAvailable => _isUpdateAvailable;

  Stream<int>? downloadAndInstallUpdate() {
    if (!_isUpdateAvailable || _asset == null) return null;
    final controller = StreamController<int>.broadcast();
    () async {
      final tempDir = await getTemporaryDirectory();
      final sha256r = await _dio.get(
          '$_githubBaseUrl/releases/assets/${_asset!.sha256Id}',
          options: Options(headers: {'accept': 'application/octet-stream'}));
      if (sha256r.data == null) {
        throw Exception('could not get sha256 for release');
      }
      final sha256 = (sha256r.data as String).trim();
      final updatesDir =
          await Directory('${tempDir.path}${Platform.pathSeparator}updates')
              .create();
      final updateFile =
          File('${updatesDir.path}${Platform.pathSeparator}update.apk');
      int lastProgress = 0;
      final updateContent = await _dio
          .get<Uint8List>('$_githubBaseUrl/releases/assets/${_asset!.apkId}',
              onReceiveProgress: (loaded, total) {
        int progress = loaded * 100 ~/ total;
        if (progress == lastProgress) return;
        lastProgress = progress;
        controller.add(progress);
      },
              options: Options(
                  headers: {'accept': 'application/octet-stream'},
                  responseType: ResponseType.bytes));
      if (updateContent.data == null) {
        return controller.addError(UpdaterError());
      }
      final update = updateContent.data!;
      final digest = crypto.sha256.convert(update).toString();
      if (digest != sha256) {
        controller
            .addError(UpdaterError(type: UpdaterErrorType.sha256Mismatch));
        _logger.severe(
            'downloaded update file is not valid, sha256 mismatch:\n$sha256 != $digest');
        return;
      }
      // update is valid
      _logger.info('downloaded update file is valid!');
      await updateFile.writeAsBytes(update);
      await InternalAPIWrapper().installAPK(updateFile.path);
    }()
        .whenComplete(() => controller.close());
    return controller.stream;
  }

  void ignoreCurrentUpdate() {
    if (_updateId != null) _updaterCache.ignoreUpdate = _updateId;
  }
}

enum UpdaterErrorType {
  generic,
  sha256Mismatch,
}

extension AsString on UpdaterErrorType {
  String asString(BuildContext context) {
    switch (this) {
      case UpdaterErrorType.generic:
        return AppLocalizations.of(context).updaterErrorDownload;
      case UpdaterErrorType.sha256Mismatch:
        return AppLocalizations.of(context).updateCorruptedNotificationSubtitle;
    }
  }
}

class UpdaterError implements Exception {
  final UpdaterErrorType type;
  UpdaterError({this.type = UpdaterErrorType.generic});

  @override
  String toString() {
    return '$runtimeType(${type.toString()})';
  }
}

@HiveType(typeId: 12)
class _Release {
  @HiveField(0)
  final int apkId;
  @HiveField(1)
  final int sha256Id;
  const _Release({
    required this.apkId,
    required this.sha256Id,
  });
}
