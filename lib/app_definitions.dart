import 'dart:async';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:json_annotation/json_annotation.dart';

import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/internal_api_wrapper/native_platform.dart';
import 'package:uploadgram/internal_api_wrapper/updater.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';
import 'package:uploadgram/widgets/popup_menu_item_icon.dart';

import 'main.dart';

part 'app_definitions.g.dart';

@HiveType(typeId: 2)
enum FilesTheme {
  @HiveField(0)
  grid,
  @HiveField(1)
  gridCompact,
  @HiveField(2)
  list
}
@HiveType(typeId: 3)
enum FabTheme {
  @HiveField(0)
  centerExtended,
  @HiveField(1)
  left
}

const double gridBorderRadius = 15.0;
const double listBorderRadius = 15.0;

class UploadingFileWidget extends StatelessWidget {
  final Widget Function(bool uploading, double? progress, String? error,
      int bytesPerSec, UploadedFile file) builder;
  final UploadingFile file;
  const UploadingFileWidget(
      {Key? key, required this.builder, required this.file})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UploadingEvent>(
        stream: file.stream,
        builder:
            (BuildContext context, AsyncSnapshot<UploadingEvent> snapshot) {
          double? progress;
          String? error;
          int bytesPerSec = 0;
          bool uploading = true;
          UploadedFile? file = UploadedFile(
            name: this.file.file.name,
            size: this.file.file.size,
            url: '',
            delete: null,
          );
          if (snapshot.hasData) {
            switch (snapshot.connectionState) {
              case ConnectionState.active:
                if (snapshot.data is UploadingEventProgress) {
                  progress = (snapshot.data as UploadingEventProgress).progress;
                  bytesPerSec =
                      (snapshot.data as UploadingEventProgress).bytesPerSec;
                }
                break;
              case ConnectionState.done:
                if (snapshot.data is UploadingEventResponse) {
                  uploading = false;
                  var response = snapshot.data as UploadingEventResponse;
                  file =
                      file.copyWith(url: response.url, delete: response.delete);
                  break;
                }
                break;
              default:
                break;
            }
          } else if (snapshot.hasError) {
            uploading = false;
            if (snapshot.error is UploadingEventError) {
              final snError = snapshot.error as UploadingEventError;
              if (snError.errorType == UploadingEventErrorType.canceled) {
                error = AppLocalizations.of(context).uploadCanceled;
              } else {
                if (snError.message == null) {
                  error = AppLocalizations.of(context)
                      .errorCouldNotUploadFile(snError.statusCode!);
                } else {
                  error = snError.message;
                }
              }
            } else {
              error = snapshot.error!.toString();
            }
          }
          return InkWell(
              child: IgnorePointer(
                  child:
                      builder(uploading, progress, error, bytesPerSec, file)),
              onTap: () => showModalBottomSheet(
                    context: context,
                    builder: (context) =>
                        Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        leading: const Icon(Icons.cancel),
                        title: const Text(''),
                        onTap: () =>
                            WebAPIWrapper().cancelUpload(this.file.taskId),
                      ),
                    ]),
                  ));
        });
  }
}

abstract class FilesViewerTheme extends StatefulWidget {
  const FilesViewerTheme({Key? key}) : super(key: key);
}

class FileRightClickListener extends StatelessWidget {
  final String? delete;
  final Function(String, {Function? onYes})? handleDelete;
  final Function(String, {Function(String)? onDone, String? oldName})?
      handleRename;
  final ValueNotifier<String> filenameNotifier;
  final int size;
  final String url;
  final Widget child;

  const FileRightClickListener({
    Key? key,
    required this.delete,
    required this.filenameNotifier,
    required this.handleDelete,
    required this.handleRename,
    required this.size,
    required this.url,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: delete != null
          ? (PointerDownEvent event) {
              if (event.buttons != kSecondaryMouseButton) return;
              final overlay =
                  Overlay?.of(context)?.context.findRenderObject() as RenderBox;
              final localizations = AppLocalizations.of(context);
              showMenu<RightClickContextMenuActions>(
                  context: context,
                  position: RelativeRect.fromSize(
                      event.position & Size.zero, overlay.size),
                  items: [
                    PopupMenuItemIcon(
                      value: RightClickContextMenuActions.delete,
                      icon: const Icon(Icons.delete),
                      child: Text(localizations.deleteText),
                    ),
                    PopupMenuItem(
                        value: RightClickContextMenuActions.rename,
                        child: Row(children: [
                          const Icon(Icons.edit),
                          const SizedBox(width: 15),
                          Text(localizations.renameText),
                        ])),
                    PopupMenuItemIcon(
                      value: RightClickContextMenuActions.copy,
                      icon: const Icon(Icons.copy),
                      child: Text(localizations.linkCopyText),
                    ),
                    PopupMenuItemIcon(
                      value: RightClickContextMenuActions.export,
                      icon: const Icon(Icons.get_app),
                      child: Text(localizations.exportText),
                    ),
                  ]).then((value) {
                switch (value!) {
                  case RightClickContextMenuActions.delete:
                    handleDelete?.call(delete!);
                    break;
                  case RightClickContextMenuActions.rename:
                    handleRename?.call(delete!,
                        oldName: filenameNotifier.value,
                        onDone: (String newName) =>
                            filenameNotifier.value = newName);
                    break;
                  case RightClickContextMenuActions.copy:
                    AppLogic.copy(url).then((didCopy) =>
                        ScaffoldMessenger.of(context).snack(didCopy
                            ? localizations.linkCopySuccessful
                            : localizations.linkCopyError));
                    break;
                  case RightClickContextMenuActions.export:
                    InternalAPIWrapper.instance.exportFiles({
                      delete!: UploadedFile(
                          delete: null,
                          name: filenameNotifier.value,
                          size: size,
                          url: url),
                    });
                    break;
                }
              });
            }
          : null,
      child: child,
    );
  }
}

enum RightClickContextMenuActions { copy, delete, rename, export }

@HiveType(typeId: 1)
enum Themes {
  @HiveField(0)
  system,
  @HiveField(1)
  dark,
  @HiveField(2)
  light
}

MaterialColor get _primarySwatch => MaterialColor(Settings.themeAccent.value, {
      50: Settings.themeAccent.withOpacity(.1),
      100: Settings.themeAccent.withOpacity(.2),
      200: Settings.themeAccent.withOpacity(.3),
      300: Settings.themeAccent.withOpacity(.4),
      400: Settings.themeAccent.withOpacity(.5),
      500: Settings.themeAccent.withOpacity(.6),
      600: Settings.themeAccent.withOpacity(.7),
      700: Settings.themeAccent.withOpacity(.8),
      800: Settings.themeAccent.withOpacity(.9),
      900: Settings.themeAccent.withOpacity(1),
    });

Map<Themes, ThemeData> get themes => {
      Themes.dark: ThemeData(
        primaryColor: Settings.themeAccent,
        appBarTheme: const AppBarTheme(color: Color(0xFF222222)),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF222222), foregroundColor: Colors.white),
        primarySwatch: _primarySwatch,
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: _primarySwatch,
            accentColor: Settings.themeAccent,
            brightness: Brightness.dark),
        primaryColorDark: Colors.grey[900],
        primaryColorLight: Settings.themeAccent,
        primaryIconTheme: const IconThemeData(color: Colors.white),
        primaryColorBrightness: Brightness.dark,
        brightness: Brightness.dark,
        canvasColor: Colors.black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        toggleableActiveColor: Settings.themeAccent,
      ),
      Themes.light: ThemeData(
        primarySwatch: _primarySwatch,
        primaryColorDark: Colors.grey[300],
        colorScheme: ColorScheme.fromSwatch(
            primarySwatch: _primarySwatch,
            accentColor: Settings.themeAccent,
            brightness: Brightness.light),
        primaryColorLight: Settings.themeAccent,
        brightness: Brightness.light,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        toggleableActiveColor: Settings.themeAccent,
      ),
    };

class AppRebuildNotification extends Notification {}

enum UploadgramMoreSettingsAction {
  exportFiles,
  importFiles,
  settingsTile,
  aboutTile,
  downloadApp,
}
@HiveType(typeId: 4)
enum SortBy {
  @HiveField(0)
  name,
  @HiveField(1)
  size,
  @HiveField(2)
  uploadDate,
}

@HiveType(typeId: 5)
enum SortType {
  @HiveField(0)
  descending,
  @HiveField(1)
  ascending,
}

@HiveType(typeId: 0)
class SortOptions {
  @HiveField(0)
  final SortBy sortBy;
  @HiveField(1)
  final SortType sortType;
  const SortOptions({
    required this.sortBy,
    required this.sortType,
  });
}

@JsonSerializable()
@HiveType(typeId: 7)
class UploadgramLogRecord {
  @HiveField(0)
  final DateTime time;
  @HiveField(1)
  final String loggerName;
  @HiveField(2)
  final String message;
  @HiveField(3)
  @JsonKey(fromJson: _levelFromJson, toJson: _levelToJson)
  final Level level;
  const UploadgramLogRecord({
    required this.time,
    required this.loggerName,
    required this.message,
    required this.level,
  });

  static Level _levelFromJson(List value) =>
      Level(value[0] as String, value[1] as int);
  static List _levelToJson(Level value) => [value.name, value.value];

  factory UploadgramLogRecord.fromLogRecord(LogRecord record) =>
      UploadgramLogRecord(
        time: record.time,
        loggerName: record.loggerName,
        message: record.message,
        level: record.level,
      );

  factory UploadgramLogRecord.fromJson(Map<String, dynamic> json) =>
      _$UploadgramLogRecordFromJson(json);

  Map toJson() => _$UploadgramLogRecordToJson(this);

  String format() => '[${time.toLocal()}] $loggerName ${level.name}: $message';
}

class LevelAdapter extends TypeAdapter<Level> {
  @override
  int get typeId => 9;

  @override
  void write(BinaryWriter writer, Level obj) =>
      writer.writeList(UploadgramLogRecord._levelToJson(obj));

  @override
  Level read(BinaryReader reader) =>
      UploadgramLogRecord._levelFromJson(reader.readList());
}

class DateTimeAdapter extends TypeAdapter<DateTime> {
  @override
  int get typeId => 8;

  @override
  void write(BinaryWriter writer, DateTime obj) =>
      writer.writeInt(obj.millisecondsSinceEpoch);

  @override
  DateTime read(BinaryReader reader) =>
      DateTime.fromMillisecondsSinceEpoch(reader.readInt());
}

extension SnackQuickAction on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> snack(
    String content, {
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    SnackBarAction? action,
    Duration? duration,
  }) =>
      showSnackBar(SnackBar(
          content: Text(content),
          behavior: behavior,
          duration: duration ?? const Duration(seconds: 4),
          action: action
          //??SnackBarAction(
          //        label: AppLocalizations.of(context)!.actionSnackbarDismiss,
          //        onPressed: () => null),
          ));
}

extension LastEntry<E> on List<E> {
  /// Gets the last entry of a list (equivalent to `this[this.length - 1]`)
  ///
  /// It is recommended to use this instead of `.last`, this accesses the entry directly,
  /// `.last` will iterate through the previous elements as well.
  E get lastEntry {
    if (length == 0) throw StateError('This list is empty');
    return this[length - 1];
  }
}

extension Format on LogRecord {
  String format() => '[${time.toLocal()}] [$loggerName] $message';
}

/// Uses [path.extension] but returns the extension without a dot (.)
String extension(String filename, [int level = 1]) {
  String ext = path.extension(filename, level);
  if (ext.length < 2) return '';
  return ext.substring(1);
}

Future<bool> _showProgressNotification(int? progress,
        {required BuildContext context}) =>
    AwesomeNotifications().createNotification(
        content: NotificationContent(
      id: 0,
      channelKey: downloadProgressChannel,
      title: AppLocalizations.of(context).downloadingUpdateNotificationTitle,
      body: progress == null ? null : '$progress%',
      progress: progress,
      notificationLayout: NotificationLayout.ProgressBar,
      color: Settings.themeAccent,
    ));

Future<bool?> checkForUpdates(
  BuildContext context, {
  bool force = false,
  bool countIgnoredUpdates = false,
  bool shouldShowNotification = true,
}) {
  detachDialog(Stream<int> stream) {
    late final StreamSubscription nSubscription;
    nSubscription = stream.listen((event) {
      _showProgressNotification(event, context: context);
    }, onDone: () {
      AwesomeNotifications().cancel(0);
      nSubscription.cancel();
    }, onError: (err) {
      if (err is UpdaterError) {
        AwesomeNotifications().createNotification(
            content: NotificationContent(
          id: 0,
          channelKey: downloadProgressChannel,
          title: AppLocalizations.of(context).updateCorruptedNotificationTitle,
          body: err.type.asString(context),
          color: Settings.themeAccent,
        ));
      }
      Logger('Updater').severe(err.toString());
    });
  }

  if (InternalAPIWrapper.isNative) {
    return Updater()
        .checkForUpdates(force: force, countIgnoredUpdates: countIgnoredUpdates)
        .then((isUpdateAvailable) {
      if (isUpdateAvailable == null) return null;
      if (isUpdateAvailable) {
        if (shouldShowNotification) {
          AwesomeNotifications().createNotification(
              content: NotificationContent(
                id: 0,
                channelKey: newUpdateChannel,
                title: AppLocalizations.of(context).newUpdateNotificationTitle,
                body: Updater().changelog,
                color: Settings.themeAccent,
              ),
              actionButtons: [
                NotificationActionButton(
                    key: 'ignore_update',
                    label: AppLocalizations.of(context)
                        .newUpdateNotificationBtnIgnore,
                    buttonType: ActionButtonType.KeepOnTop),
                NotificationActionButton(
                    key: 'download_update',
                    label: AppLocalizations.of(context)
                        .newUpdateNotificationBtnDownload,
                    buttonType: ActionButtonType.KeepOnTop),
              ]);
        }
        final localizations = AppLocalizations.of(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(localizations.updaterUpdateAvailable),
            content: Text(Updater().changelog ?? ''),
            actions: [
              TextButton(
                  child: Text(localizations.updaterIgnore),
                  onPressed: () {
                    Updater().ignoreCurrentUpdate();
                    Navigator.pop(context);
                  }),
              TextButton(
                  child: Text(localizations.updaterNotNow),
                  onPressed: () => Navigator.pop(context)),
              TextButton(
                child: Text(localizations.updaterDownload),
                onPressed: () {
                  Navigator.pop(context);
                  final stream = Updater().downloadAndInstallUpdate();
                  if (stream != null) {
                    showDialog(
                        context: context,
                        builder: (context) => _DownloadingUpdateDialog(
                            stream: stream, detach: detachDialog));
                  }
                },
              ),
            ],
          ),
        );
      }
      return isUpdateAvailable;
    });
  }
  return Future.value();
}

class _DownloadingUpdateDialog extends StatefulWidget {
  final Stream<int> stream;
  final Function(Stream<int>) detach;
  const _DownloadingUpdateDialog({
    Key? key,
    required this.stream,
    required this.detach,
  }) : super(key: key);

  @override
  __DownloadingUpdateDialogState createState() =>
      __DownloadingUpdateDialogState();
}

class __DownloadingUpdateDialogState extends State<_DownloadingUpdateDialog> {
  late final StreamSubscription _subscription;
  String? _error;

  @override
  void initState() {
    _subscription = widget.stream.listen(null,
        onDone: () {
          if (_error == null) Navigator.pop(context);
        },
        onError: (err) => setState(() {
              if (err is UpdaterError) {
                switch (err.type) {
                  case UpdaterErrorType.generic:
                    _error = AppLocalizations.of(context).updaterErrorDownload;
                    break;
                  case UpdaterErrorType.sha256Mismatch:
                    _error = AppLocalizations.of(context)
                        .updateCorruptedNotificationSubtitle;
                    break;
                }
              } else {
                _error = err.toString();
              }
            }));
    super.initState();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(_error == null
          ? localizations.downloadingUpdateNotificationTitle
          : localizations.updateCorruptedNotificationTitle),
      content: _error == null
          ? StreamBuilder<int>(
              stream: widget.stream,
              builder: (context, snapshot) => Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                        value: snapshot.data == null
                            ? null
                            : snapshot.data! / 100),
                  ),
                  if (snapshot.data != null) ...[
                    const SizedBox(width: 16.0),
                    Text('${snapshot.data}%'),
                  ]
                ],
              ),
            )
          : Text(_error!),
      actions: [
        _error == null
            ? TextButton(
                child: Text(localizations.updaterHideProgressButton),
                onPressed: () {
                  Navigator.pop(context);
                  widget.detach.call(widget.stream);
                  ScaffoldMessenger.of(context)
                      .snack(localizations.updaterCheckProgressInNotifications);
                },
              )
            : TextButton(
                child: Text(localizations.actionSnackbarDismiss),
                onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}
