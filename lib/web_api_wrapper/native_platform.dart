import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:duration/duration.dart';
import 'package:duration/locale.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http_parser/http_parser.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart' as synchronized;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/internal_api_wrapper/native_platform.dart';
import 'package:uploadgram/main.dart';
import 'package:uploadgram/utils.dart';
import 'package:uploadgram/mime_types.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/native.dart';

const String uiUploaderSendPortName = 'ui_uploader_sendport';
const String uploaderUiSendPortName = 'uploader_ui_sendport';

class WebAPIWrapper {
  static final instance = WebAPIWrapper._();
  factory WebAPIWrapper() => instance;
  WebAPIWrapper._();

  final _dio = Dio(BaseOptions(
    followRedirects: true,
    validateStatus: (status) => true,
    responseType: ResponseType.json,
  ));

  void downloadApp() {}

  Future<Map?> getFile(String deleteId) async {
    final response =
        await _dio.get('https://${settings.endpoint.api}/get/$deleteId');
    try {
      return json.decode(response.data);
    } catch (e) {
      return null;
    }
  }

  Future<void> enqueueUpload(UploadgramFile file) =>
      UploaderImpl().enqueue(file);

  FutureOr<void> ensureInitialized() => UploaderImpl().ensureInitialized();

  List<UploadingFile> get queue => UploaderImpl().queue;

  Future<DeleteApiResponse> deleteFile(String file) async {
    Response response =
        await _dio.get('https://${settings.endpoint.api}/delete/$file');
    if (response.statusCode != 200 || response.data is! Map) {
      return DeleteApiResponse(ok: false, statusCode: response.statusCode!);
    }
    return DeleteApiResponse.fromJson(response.data);
  }

  Future<RenameApiResponse> renameFile(String file, String newName) async {
    Response response = await _dio.post(
        'https://${settings.endpoint.api}/rename/$file',
        data: {'new_filename': await Utils.parseName(newName)});
    if (response.statusCode != 200) {
      final altMessage =
          'Error ${response.statusCode}: ${response.statusMessage}';
      return RenameApiResponse(
          ok: false,
          statusCode: response.statusCode!,
          errorMessage: response.data is Map
              ? (response.data?['message'] ?? altMessage)
              : altMessage);
    }
    return RenameApiResponse.fromJson(response.data);
  }

  Future<bool> checkNetwork() async {
    try {
      Response response =
          await _dio.head('https://${settings.endpoint.api}/status');
      if (response.statusCode != 200) {
        return false;
      }
      return true;
    } on DioError {
      return false;
    }
  }

  FutureOr<void> cancelUpload(String taskId) =>
      UploaderImpl().cancelUpload(taskId);
}

abstract class UploaderImpl {
  static UploaderImpl? _instance;

  /// Gives you the previous instance if there was another one already,
  /// otherwise constructs a new class (singleton constructor)
  ///
  /// Will return a [_BackgroundUploaderImpl] if the running system is Android or iOS,
  /// [_ForegroundUploaderImpl] otherwise.
  factory UploaderImpl() => _instance ??= Platform.isAndroid || Platform.isIOS
      ? _BackgroundUploaderImpl()
      : _ForegroundUploaderImpl();

  /// If this is a [_BackgroundUploaderImpl], this will return a future
  /// that will be completed when the queue has been gotten from the background process if it's running,
  /// otherwise, this future will be completed once the sendPort becomes available.
  FutureOr<void> ensureInitialized();

  /// Enqueues the given [file]
  Future<void> enqueue(UploadgramFile file);

  /// Gives you the queued uploads
  ///
  /// If you want the queue to have the previous elements,
  /// make sure to call [ensureInitialized] before getting the queued uploads!
  List<UploadingFile> get queue;

  /// Cancel an upload by its [taskId]
  FutureOr<void> cancelUpload(String taskId);
}

class _BackgroundUploaderImpl implements UploaderImpl {
  final _receivePort = ReceivePort();
  Future<void>? _future;
  SendPort? _sendPortInstance;
  List<UploadingFile> _queue = [];

  static final _logger = Logger('_BackgroundUploaderImpl');

  SendPort? get _sendPort => _sendPortInstance ??=
      IsolateNameServer.lookupPortByName(uiUploaderSendPortName);

  _BackgroundUploaderImpl() {
    IsolateNameServer.removePortNameMapping(uploaderUiSendPortName);
    if (IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, uploaderUiSendPortName)) {
      FlutterUploader().setBackgroundHandler(_backgroundIsolate);
    } else {
      throw Exception('Could not register the uploader to ui sendPort.');
    }
    if (_sendPort != null) {
      _sendPort!.send(_BackgroundIsolateRequest(
          type: _BackgroundIsolateTask.getQueue, message: null));
      _future = _receivePort
          .firstWhere((element) =>
              element is _BackgroundIsolateResponse &&
              element.forTask == _BackgroundIsolateTask.getQueue &&
              element.value is List<UploadingFile>)
          .then<void>((element) {
        assert(element is _BackgroundIsolateResponse);
        var value = (element as _BackgroundIsolateResponse).value
            as List<UploadingFile>;
        _queue = value
            .map<UploadingFile>((e) => e.copyWith(
                stream: _getEventStreamForTaskId(e.taskId, uploadingFile: e)))
            .toList();
        _future = null;
      });
    } else {
      _future = null;
    }
    waitForSendPort()
        .then((value) => onLocaleChanged(AppLogic.currentLocale.value))
        .then((value) => onAccentChanged(AppLogic.currentAccent.value));
    AppLogic.currentLocale
        .addListener(() => onLocaleChanged(AppLogic.currentLocale.value));

    AppLogic.currentAccent
        .addListener(() => onAccentChanged(AppLogic.currentAccent.value));
  }

  void onLocaleChanged(Locale? locale) {
    if (_sendPort != null && locale != null) {
      _sendPort!.send(_BackgroundIsolateRequest(
          type: _BackgroundIsolateTask.changeLocale, message: locale));
    }
  }

  void onAccentChanged(Color color) {
    if (_sendPort != null) {
      _sendPort!.send(_BackgroundIsolateRequest(
          type: _BackgroundIsolateTask.changeAccent, message: color));
    }
  }

  Future<void> waitForSendPort() async {
    while (_sendPort == null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  @override
  FutureOr<void> ensureInitialized() => _future;

  @override
  List<UploadingFile> get queue => _queue;

  @override
  Future<void> enqueue(UploadgramFile file) async {
    String taskId = await FlutterUploader().enqueue(MultipartFormDataUpload(
        url: 'https://${settings.endpoint.api}/upload',
        method: UploadMethod.POST,
        data: {
          'file_size': file.size.toString()
        },
        files: [
          FileItem(path: (file.realFile as File).path, field: 'file_upload')
        ]));

    // Wait for the isolate to start, if it isn't running already
    await waitForSendPort();
    if (_future != null) await _future;
    final uploadingFile = UploadingFile(file: file, taskId: taskId);
    _sendPort!.send(_BackgroundIsolateRequest(
        type: _BackgroundIsolateTask.enqueueFile, message: uploadingFile));
    // Add to queues
    _queue.add(uploadingFile);
    uploadingFile.stream =
        _getEventStreamForTaskId(taskId, uploadingFile: uploadingFile);
  }

  Stream<UploadingEvent> _getEventStreamForTaskId(String taskId,
      {UploadingFile? uploadingFile}) {
    uploadingFile ??= _queue.firstWhere((element) => element.taskId == taskId);
    if (uploadingFile.stream != null) return uploadingFile.stream!;
    uploadingFile.startedUploadingAt ??= DateTime.now();
    final controller = StreamController<UploadingEvent>.broadcast();
    final subscription = FlutterUploader()
        .progress
        .where((event) => event.taskId == taskId)
        .listen((event) {
      if (event.progress == null || event.progress! <= -1) return;
      final int loaded =
          (event.progress ?? 0) * uploadingFile!.file.size ~/ 100;
      int time = DateTime.now()
          .difference(uploadingFile.startedUploadingAt!)
          .abs()
          .inSeconds;
      if (time == 0) time = 1;
      controller.add(UploadingEventProgress(
          progress: (event.progress ?? 0) / 100, bytesPerSec: loaded ~/ time));
    });
    FlutterUploader()
        .result
        .firstWhere((event) =>
            event.taskId == taskId &&
            ((event.status == UploadTaskStatus.complete &&
                    event.response != null) ||
                (event.status == UploadTaskStatus.canceled ||
                    event.status == UploadTaskStatus.failed)))
        .then<UploadingEventResponse>((event) {
          _queue.removeWhere((element) => element.taskId == taskId);
          if (event.statusCode == 200) {
            // Tell the background isolate that foreground is gonna save this file.
            _sendPort!.send(_BackgroundIsolateRequest(
                type: _BackgroundIsolateTask.dontSaveFile, message: null));
            _logger.fine(event.response);
            final decodedResp = json.decode(event.response!);
            if (decodedResp['ok']) {
              final response = UploadingEventResponse.fromJson(decodedResp);

              // Actually save the file
              UploadedFiles().add(UploadedFile(
                  name: uploadingFile!.file.name,
                  size: uploadingFile.file.size,
                  url: response.url,
                  delete: response.delete));
              return response;
            }
            throw UploadingEventError(
                errorType: UploadingEventErrorType.generic,
                message: decodedResp['message']);
          }
          if (event.status == UploadTaskStatus.canceled) {
            throw UploadingEventError(
                errorType: UploadingEventErrorType.canceled, message: '');
          }

          throw UploadingEventError(
              errorType: UploadingEventErrorType.generic,
              message: null,
              statusCode: event.statusCode);
        })
        .then((event) => controller.add(event))
        .catchError((err, stacktrace) => controller.addError(err))
        .whenComplete(() {
          subscription.cancel();
          controller.close();
        });
    return controller.stream;
  }

  @override
  Future<void> cancelUpload(String taskId) {
    return FlutterUploader().cancel(taskId: taskId);
  }
}

enum _BackgroundIsolateTask {
  getQueue,
  enqueueFile,
  changeLocale,
  changeAccent,
  dontSaveFile,
}

class _BackgroundIsolateRequest {
  final _BackgroundIsolateTask type;
  final Object? message;
  _BackgroundIsolateRequest({
    required this.type,
    required this.message,
  });

  @override
  String toString() => '_BackgroundIsolateRequest($type, $message)';
}

class _BackgroundIsolateResponse {
  final _BackgroundIsolateTask forTask;
  final Object value;
  _BackgroundIsolateResponse({
    required this.forTask,
    required this.value,
  });
}

Future<void> _backgroundIsolate() {
  WidgetsFlutterBinding.ensureInitialized();
  return InternalAPIWrapper()
      .setupLoggerIsolate()
      .then((value) => _BackgroundIsolateHandler());
}

class _BackgroundIsolateHandler {
  final ReceivePort _receivePort =
      ReceivePort('Background isolate receive port');
  final List<UploadingFile> _queue = [];

  static final _logger = Logger('_BackgroundIsolateHandler');

  AppLocalizations? localizations;
  DurationLocale? durationLocale;
  Color? accent;

  final List<Timer> _saveFileList = [];

  bool didInitializeNotifications = false;

  static _BackgroundIsolateHandler? _instance;

  factory _BackgroundIsolateHandler() =>
      _instance ??= _BackgroundIsolateHandler._();

  _BackgroundIsolateHandler._() {
    _logger.info('initializing background isolate...');
    _logger.fine('registering sendport...');
    IsolateNameServer.removePortNameMapping(uiUploaderSendPortName);
    IsolateNameServer.registerPortWithName(
        _receivePort.sendPort, uiUploaderSendPortName);

    _receivePort.listen((message) {
      _logger.finer('Received message from UI Isolate');
      _logger.finest(message.toString());
      assert(message is _BackgroundIsolateRequest,
          'Received message is not a _BackgroundIsolateRequest.');
      _instance!.onMessage(message);
    });

    // Clear older uploads
    FlutterUploader().clearUploads();

    // Set up flutter_uploader's result and progress handlers.
    FlutterUploader().progress.listen(onUploadProgress);
    FlutterUploader().result.listen(onUploadResult);

    // Set up notifications
    // final androidInitializationSettings =
    //     AndroidInitializationSettings('icon_64');
    // _flutterLocalNotifications.initialize(
    //     InitializationSettings(android: androidInitializationSettings));
    AwesomeNotifications().actionStream.listen(onNotificationAction);

    getApplicationSupportDirectory().then((value) => Hive.init(value.path));
  }

  void onNotificationAction(ReceivedAction action) {
    if (action.buttonKeyPressed.startsWith('cancel_')) {
      final taskId = action.buttonKeyPressed.substring('cancel_'.length);
      _logger.info('canceling $taskId...');
      FlutterUploader()
          .cancel(taskId: taskId)
          .then((value) => _logger.info('$taskId canceled successfully'));
    }
  }

  SendPort? get _sendPort =>
      IsolateNameServer.lookupPortByName(uploaderUiSendPortName);

  void onMessage(_BackgroundIsolateRequest request) {
    switch (request.type) {
      case _BackgroundIsolateTask.getQueue:
        _sendPort!.send(
            _BackgroundIsolateResponse(forTask: request.type, value: _queue));
        break;
      case _BackgroundIsolateTask.enqueueFile:
        assert(request.message is UploadingFile,
            'Message in enqueue request isn\'t an UploadingFile');
        onEnqueued(request.message as UploadingFile);
        break;
      case _BackgroundIsolateTask.changeLocale:
        assert(request.message is Locale);
        _logger.info('Loading new locale\'s resources...');
        durationLocale = DurationLocale.fromLanguageCode(
                (request.message as Locale).languageCode) ??
            const EnglishDurationLocale();
        AppLocalizations.delegate
            .load(request.message as Locale)
            .then((value) =>
                initializeOrRefreshNotifications(localizations = value))
            .then((value) => _logger.info('Locales loaded.'));

        break;
      case _BackgroundIsolateTask.changeAccent:
        accent = request.message as Color;
        break;
      case _BackgroundIsolateTask.dontSaveFile:
        _logger.info('deleting all queued file saves');
        _saveFileList
          ..forEach((timer) => timer.cancel())
          ..clear();
        break;
    }
  }

  void onEnqueued(UploadingFile file) => _queue.add(file);

  void onUploadProgress(UploadTaskProgress event) {
    if (event.progress == null || event.progress! <= -1) return;
    UploadingFile? _currentUploadingFile = _getUploadingFileFor(event.taskId);
    if (_currentUploadingFile == null) return;
    _currentUploadingFile.startedUploadingAt ??= DateTime.now();

    // Don't show the notifications if we don't yet have the localization strings
    if (localizations == null) {
      _logger.warning(
          'Not showing the notification due to missing localizations.');
      return;
    }
    final file = _currentUploadingFile.file;
    final notifTitle = file.name.length > 25
        ? '${file.name.substring(0, 17)}...${file.name.substring(file.name.length - 8)}'
        : file.name;
    final int loaded = (event.progress ?? 0) * file.size ~/ 100;
    final int time = DateTime.now()
        .difference(_currentUploadingFile.startedUploadingAt!)
        .abs()
        .inSeconds;
    final int bytesPerSec = loaded ~/ (time == 0 ? 1 : time);
    final Duration willComplete = Duration(
        seconds: bytesPerSec == 0 ? 0 : (file.size - loaded) ~/ bytesPerSec);
    AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: event.taskId.hashCode,
          channelKey: uploadingNotificationChannel,
          title: notifTitle,
          body: '${Utils.humanSize(bytesPerSec)}/s - ${event.progress ?? 0}%',
          ticker: localizations!.secondsRemaining(
              prettyDuration(willComplete, locale: durationLocale!)),
          progress: event.progress,
          notificationLayout: NotificationLayout.ProgressBar,
          color: accent ?? Colors.blue,
          locked: true,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'cancel_${event.taskId}',
            label: 'Cancel',
            buttonType: ActionButtonType.KeepOnTop,
          ),
        ]);
    // String stringRemaining = (secondsRemaining >= 3600
    //         ? (secondsRemaining ~/ 3600).toString() + ' hours '
    //         : '') +
    //     ((secondsRemaining %= 3600) >= 60
    //         ? (secondsRemaining ~/ 60).toString() + ' minutes '
    //         : '');
    // // just to avoid having 'remaining' as string
    // stringRemaining = stringRemaining +
    //     ((secondsRemaining > 0 || stringRemaining.isEmpty)
    //         ? '${secondsRemaining % 60} seconds '
    //         : '') +
    //     'remaining';
    // _flutterLocalNotifications.show(
    //     event.taskId.hashCode,
    //     notifTitle,
    //     '${Utils.humanSize(bytesPerSec)}/s - ${event.progress ?? 0}%',
    //     NotificationDetails(
    //         android: AndroidNotificationDetails(
    //       'com.pato05.uploadgram/notifications/upload',
    //       localizations!.uploadProgressNotificationTitle,
    //       localizations!.uploadProgressNotificationDetails,
    //       subText: localizations!.secondsRemaining(
    //           prettyDuration(willComplete, locale: durationLocale!)),
    //       channelShowBadge: false,
    //       importance: Importance.low,
    //       onlyAlertOnce: true,
    //       showProgress: true,
    //       playSound: false,
    //       ongoing: true,
    //       maxProgress: 100,
    //       progress: event.progress ?? 0,
    //       color: accent ?? Colors.blue,
    //       enableVibration: false,
    //       enableLights: false,
    //     )));
  }

  UploadingFile? _getUploadingFileFor(String taskId) =>
      _queue.firstWhereOrNull((element) => taskId == element.taskId);

  bool _isCompleted(UploadTaskStatus status) => const [
        UploadTaskStatus.complete,
        UploadTaskStatus.failed,
        UploadTaskStatus.canceled
      ].contains(status);

  void onUploadResult(UploadTaskResponse response) async {
    final _currentUploadingFile = _getUploadingFileFor(response.taskId);
    if (_currentUploadingFile == null) return;
    if (localizations == null) {
      _logger.severe(
          'Didn\'t receive any localizations after the upload has been completed.');
      return;
    }
    final uploadStatusToString = {
      UploadTaskStatus.complete: localizations!.uploadCompletedNotification,
      UploadTaskStatus.failed: localizations!.uploadFailedNotification,
      UploadTaskStatus.paused: localizations!.uploadPausedNotification,
    };
    if (!_isCompleted(response.status!)) return;
    if (response.status == UploadTaskStatus.canceled) {
      AwesomeNotifications().cancel(response.taskId.hashCode);
    } else {
      AwesomeNotifications().createNotification(
          content: NotificationContent(
        id: response.taskId.hashCode,
        channelKey: uploadedNotificationChannel,
        title: uploadStatusToString[response.status]!,
        body: _currentUploadingFile.file.name,
        color: accent ?? Colors.blue,
      ));
    }
    // _flutterLocalNotifications.show(
    //     response.taskId.hashCode,
    //     uploadStatusToString[response.status]!,
    //     _currentUploadingFile.file.name,
    //     NotificationDetails(
    //         android: AndroidNotificationDetails(
    //       'com.pato05.uploadgram/notifications/upload_completed',
    //       localizations!.uploadCompletedNotificationTitle,
    //       localizations!.uploadCompletedNotificationDetails,
    //       channelShowBadge: false,
    //       groupKey: _uploadedFilesGroupKey,
    //       onlyAlertOnce: false,
    //       color: accent ?? Colors.blue,
    //     )));
    if (response.statusCode == 200 &&
        response.status == UploadTaskStatus.complete) {
      _saveFileList.add(Timer(const Duration(milliseconds: 500),
          () => onUploadCompleted(response, _currentUploadingFile)));
    }
    _queue.removeWhere((element) => element.taskId == response.taskId);
    if (_queue.isEmpty) {
      _logger.info('the uploading queue is empty, calling clearUploads()...');
      await clearUploads();
    }
  }

  Future<void> onUploadCompleted(
      UploadTaskResponse response, UploadingFile uploadingFile) async {
    _logger.finest('saving: ${response.response}');
    Map resp = json.decode(response.response!);
    final uploadedFile = UploadedFile(
        url: resp['url'],
        delete: resp['delete'],
        size: uploadingFile.file.size,
        name: uploadingFile.file.name);
    await UploadedFiles.addFile(uploadedFile);
    await settings.init();
    // generate thumbnails for this file if needed
    if (canGenerateThumbnail(
        uploadingFile.file.size, uploadingFile.file.name)) {
      final thumbnailData =
          await UploadedFileThumbnail.getThumbnailData(delete: resp['delete']!);
      await UploadedFileThumbnail.generateThumbnails(
              cacheDir:
                  await getTemporaryDirectory().then((value) => value.path),
              thumbnailData: thumbnailData,
              file: (uploadingFile.file.realFile as File),
              uploadedFile: uploadedFile)
          .item2;
      await ThumbnailsMemoryCache.init();
      await ThumbnailsMemoryCache.add(uploadedFile.delete!, thumbnailData);
      await ThumbnailsMemoryCache.close();
    }
    // we can now delete the file
    await (uploadingFile.file.realFile as File).delete();
    await settings.close();
  }

  Future<void> clearUploads() {
    _logger.info('clearing processed uploads...');
    return FlutterUploader().clearUploads();
  }
}

class _ForegroundUploaderImpl implements UploaderImpl {
  final _lock = synchronized.Lock();
  final _dio =
      Dio(BaseOptions(responseType: ResponseType.json, followRedirects: true));
  final List<UploadingFile> _queue = [];
  final _cancelTokens = <String, CancelToken>{};

  @override
  FutureOr<void> ensureInitialized() {}

  @override
  Future<void> enqueue(UploadgramFile file) async {
    final cancelToken = CancelToken();
    final taskId = UniqueKey().toString();
    _cancelTokens[taskId] = cancelToken;
    final controller = StreamController<UploadingEvent>.broadcast();
    _lock.synchronized<void>(() => _uploadFile(file, controller, cancelToken));
    _queue.add(UploadingFile(
        file: file, taskId: UniqueKey().toString(), stream: controller.stream));
  }

  Future<void> _uploadFile(UploadgramFile file, StreamController controller,
      CancelToken token) async {
    MediaType mime = mimeTypes[extension(file.name).toLowerCase()] ??
        MediaType('application', 'octet-stream');
    final formData = FormData.fromMap({
      'file_size': file.size,
      'file_upload': await MultipartFile.fromFile((file.realFile as File).path,
          filename: file.name, contentType: mime),
    });
    final initDate = DateTime.now().millisecondsSinceEpoch;
    Response response;
    try {
      response = await _dio.post('https://${settings.endpoint.api}/upload',
          data: formData, cancelToken: token, onSendProgress: (loaded, total) {
        controller.add(UploadingEventProgress(
            progress: loaded / total,
            bytesPerSec: (loaded /
                    (DateTime.now().millisecondsSinceEpoch - initDate) *
                    1000)
                .toInt()));
      });
      if (response.data['ok'] as bool) {
        controller.add(UploadingEventResponse.fromJson(response.data));
      } else {
        controller.addError(UploadingEventError(
            errorType: UploadingEventErrorType.generic,
            message: response.data['message']));
      }
    } on DioError catch (e) {
      controller.addError(UploadingEventError(
          errorType: UploadingEventErrorType.generic,
          statusCode: e.response!.statusCode!,
          message:
              'Error ${e.response!.statusCode}: ${e.response!.statusMessage}'));
    } finally {
      controller.close();
    }
  }

  @override
  List<UploadingFile> get queue => _queue;

  @override
  void cancelUpload(String taskId) => _cancelTokens[taskId]?.cancel();
}
