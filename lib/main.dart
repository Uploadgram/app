import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/app_settings.dart';

import 'package:uploadgram/routes/about_route.dart';
import 'package:uploadgram/routes/settings_route.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppSettings.getSettings().then((void _) {
    runApp(UploadgramApp());
  });
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
            darkTheme: AppSettings.appTheme! == Themes.system
                ? themes[Themes.dark]
                : null,
            theme: AppSettings.appTheme! == Themes.system
                ? themes[Themes.white]
                : themes[AppSettings.appTheme!],
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
