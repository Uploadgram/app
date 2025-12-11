import 'dart:async';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/internal_api_wrapper/updater.dart';
import 'package:uploadgram/routes/about_route.dart';
import 'package:uploadgram/routes/native_only/log_route.dart';
import 'package:uploadgram/routes/settings_route.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:uploadgram/web_api_wrapper/native_platform.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/native.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    Hive
      ..registerAdapter(SortOptionsAdapter())
      ..registerAdapter(FilesThemeAdapter())
      ..registerAdapter(FabThemeAdapter())
      ..registerAdapter(ThemesAdapter())
      ..registerAdapter(SortByAdapter())
      ..registerAdapter(SortTypeAdapter())
      ..registerAdapter(ThumbnailDataAdapter())
      ..registerAdapter(DateTimeAdapter())
      ..registerAdapter(ColorAdapter())
      ..registerAdapter(LocaleAdapter());
    await settings.init();
    await setupLogger();

    AwesomeNotifications()
        .setListeners(onActionReceivedMethod: onNotificationAction);

    FlutterError.onError = (FlutterErrorDetails details) {
      assert(() {
        // ignore: avoid_print
        print(details);

        return true;
      }());
      Logger('FlutterEngine').severe(details.exceptionAsString());
    };

    runApp(const UploadgramApp());
  }, (error, stacktrace) {
    Logger('Error').severe(error.toString() + '\n\n' + stacktrace.toString());
    throw error;
  });
}

@pragma("vm:entry-point")
Future<void> onNotificationAction(ReceivedAction action) async {
  switch (action.buttonKeyPressed) {
    case 'download_update':
      Updater().downloadAndInstallUpdate();
      break;
    case 'ignore_update':
      Updater().ignoreCurrentUpdate();
      AwesomeNotifications().cancel(action.id!);
      break;
  }

  if (action.buttonKeyPressed.startsWith('cancel_')) {
    final taskId = action.buttonKeyPressed.substring('cancel_'.length);
    Logger('NotificationHandler').info('canceling $taskId...');
    await UploaderImpl().cancelUpload(taskId);
    Logger('NotificationHandler').info('$taskId canceled successfully');
    AwesomeNotifications().cancel(action.id!);
  }
}

class UploadgramApp extends StatefulWidget {
  const UploadgramApp({Key? key}) : super(key: key);

  @override
  UploadgramAppState createState() => UploadgramAppState();
}

class UploadgramAppState extends State<UploadgramApp> {
  static const _fallbackLocale = Locale('en');
  Locale _getLocale(List<Locale>? deviceLocales, Iterable<Locale> _) {
    if (deviceLocales == null) return _fallbackLocale;
    final supportedLocales = _.toList().map((e) => e.languageCode);
    return deviceLocales.firstWhere(
        (element) => supportedLocales.contains(element.languageCode),
        orElse: () => _fallbackLocale);
  }

  @override
  Widget build(BuildContext context) {
    if (settings.endpoint == null) {
      return MaterialApp(
        home: PopScope(
          canPop: false,
          onPopInvoked: (h) => setState(() {}),
          child: const Center(child: EndpointDialog()),
        ),
        darkTheme: ThemeData.dark(useMaterial3: true),
        theme: ThemeData.light(useMaterial3: true),
      );
    }

    return DynamicColorBuilder(builder: (lightScheme, darkScheme) {
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        brightness: Brightness.light,
      );
      return NotificationListener<AppRebuildNotification>(
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Uploadgram',
              darkTheme: settings.appTheme == Themes.system
                  ? theme.copyWith(brightness: Brightness.dark)
                  : null,
              theme: settings.appTheme == Themes.system ||
                      settings.appTheme == Themes.light
                  ? theme
                  : theme.copyWith(brightness: Brightness.dark),
              localeListResolutionCallback: _getLocale,
              locale: settings.locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              initialRoute: '/',
              routes: {
                '/': (BuildContext context) => const UploadgramRoute(),
                '/settings': (BuildContext context) => const SettingsRoute(),
                '/about': (BuildContext context) => const AboutRoute(),
                if (InternalAPIWrapper.isNative)
                  '/logs': (BuildContext context) => const LoggingRoute(),
              },
              onGenerateRoute: kIsWeb
                  ? (RouteSettings settings) {
                      if (settings.name != null) {
                        InternalAPIWrapper.lastUri = settings.name;
                      }
                      return null;
                    }
                  : null),
          onNotification: (_) {
            Logger('AppRebuildNotification').info('rebuiding entire app...');
            setState(() {});
            return true;
          });
    });
  }
}

const loggingSendPort = 'log_port';

void preSetupLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen(InternalAPIWrapper().log);
}

Future<void> setupLogger() async {
  preSetupLogger();
  await InternalAPIWrapper().setupLogger();
}

bool _didInitializeNotifications = false;

const uploadingNotificationChannel =
    'com.pato05.uploadgram/notifications/upload';
const uploadedNotificationChannel =
    'com.pato05.uploadgram/notifications/upload_completed';
const newUpdateChannel = 'com.pato05.uploadgram/notifications/new_update';
const downloadProgressChannel =
    'com.pato05.uploadgram/notifications/download_progress';
void initializeOrRefreshNotifications(AppLocalizations localizations) async {
  final notificationChannels = [
    NotificationChannel(
      groupKey: uploadingNotificationChannel,
      channelKey: uploadingNotificationChannel,
      channelName: localizations.uploadProgressNotificationTitle,
      channelDescription: localizations.uploadProgressNotificationDetails,
      playSound: false,
      groupAlertBehavior: GroupAlertBehavior.Children,
      channelShowBadge: false,
      enableVibration: false,
      onlyAlertOnce: true,
      importance: NotificationImportance.Low,
      defaultColor: Colors.blue,
    ),
    NotificationChannel(
      groupKey: uploadedNotificationChannel,
      channelKey: uploadedNotificationChannel,
      channelName: localizations.uploadCompletedNotificationTitle,
      channelDescription: localizations.uploadCompletedNotificationDetails,
      playSound: true,
      groupAlertBehavior: GroupAlertBehavior.Children,
      channelShowBadge: true,
      onlyAlertOnce: true,
      importance: NotificationImportance.Default,
      defaultColor: Colors.blue,
    ),
    NotificationChannel(
      groupKey: newUpdateChannel,
      channelKey: newUpdateChannel,
      channelName: localizations.uploadCompletedNotificationTitle,
      channelDescription: localizations.uploadCompletedNotificationDetails,
      playSound: true,
      groupAlertBehavior: GroupAlertBehavior.Children,
      channelShowBadge: true,
      onlyAlertOnce: true,
      importance: NotificationImportance.Default,
      defaultColor: Colors.blue,
    ),
    NotificationChannel(
      groupKey: downloadProgressChannel,
      channelKey: downloadProgressChannel,
      channelName: localizations.uploadProgressNotificationTitle,
      channelDescription: localizations.uploadProgressNotificationDetails,
      playSound: false,
      groupAlertBehavior: GroupAlertBehavior.Children,
      channelShowBadge: false,
      enableVibration: false,
      onlyAlertOnce: true,
      importance: NotificationImportance.Low,
      defaultColor: Colors.blue,
    ),
  ];
  if (!_didInitializeNotifications) {
    _didInitializeNotifications = true;
    AwesomeNotifications()
        .initialize('resource://drawable/icon_64', notificationChannels);
  }
  for (final notificationChannel in notificationChannels) {
    AwesomeNotifications().setChannel(notificationChannel, forceUpdate: true);
  }
}
