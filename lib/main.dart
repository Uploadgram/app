import 'dart:async';
import 'dart:ui';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:collection/collection.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/settings.dart';
import 'package:uploadgram/internal_api_wrapper/updater.dart';
import 'package:uploadgram/routes/about_route.dart';
import 'package:uploadgram/routes/native_only/log_route.dart';
import 'package:uploadgram/routes/settings_route.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
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

  late StreamSubscription _notificationSubscription;

  @override
  void initState() {
    _notificationSubscription =
        AwesomeNotifications().actionStream.listen((action) {
      switch (action.buttonKeyInput) {
        case 'download_update':
          Updater().downloadAndInstallUpdate();
          break;
        case 'ignore_update':
          Updater().ignoreCurrentUpdate();
          AwesomeNotifications().cancel(action.id!);
          break;
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    _notificationSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<AppRebuildNotification>(
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Uploadgram',
            darkTheme: settings.appTheme == Themes.system
                ? themes[Themes.dark]
                : themes[settings.appTheme],
            theme: settings.appTheme == Themes.system
                ? themes[Themes.light]
                : themes[settings.appTheme],
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
