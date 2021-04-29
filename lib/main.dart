import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/routes/about_route.dart';
import 'package:uploadgram/routes/settings_route.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Hive.init((await getApplicationSupportDirectory()).path);
  await AppSettings.getSettings();
  await AppLogic.getFiles();
  runApp(UploadgramApp());
}

class UploadgramApp extends StatefulWidget {
  @override
  _UploadgramAppState createState() => _UploadgramAppState();
}

class _UploadgramAppState extends State<UploadgramApp> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<AppRebuildNotification>(
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Uploadgram',
            darkTheme: AppSettings.appTheme == Themes.system
                ? themes[Themes.dark]
                : null,
            theme: AppSettings.appTheme == Themes.system
                ? themes[Themes.white]
                : themes[AppSettings.appTheme],
            initialRoute: '/',
            routes: {
              '/': (BuildContext context) => UploadgramRoute(),
              '/settings': (BuildContext context) => SettingsRoute(),
              '/about': (BuildContext context) => AboutRoute(),
            },
            onGenerateRoute: kIsWeb
                ? (RouteSettings settings) {
                    if (settings.name != null)
                      InternalAPIWrapper.lastUri = settings.name;
                    return null;
                  }
                : null),
        onNotification: (_) {
          setState(() => null);
          return true;
        });
  }
}
