import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:uploadgram/routes/about_route.dart';
import 'package:uploadgram/routes/settings_route.dart';
import 'package:uploadgram/routes/uploadgram_route.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';

void main() => runApp(UploadgramApp());

class UploadgramApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Uploadgram',
        darkTheme: ThemeData(
          appBarTheme: AppBarTheme(color: Color(0xFF222222)),
          floatingActionButtonTheme:
              FloatingActionButtonThemeData(backgroundColor: Color(0xFF222222)),
          primarySwatch: Colors.blue,
          accentColor: Colors.blue,
          primaryColorDark: Colors.grey[900],
          primaryColorLight: Colors.blue,
          primaryIconTheme: IconThemeData(color: Colors.white),
          primaryColor: Colors.blue,
          primaryColorBrightness: Brightness.dark,
          brightness: Brightness.dark,
          canvasColor: Colors.black,
        ),
        theme: ThemeData(
          appBarTheme: AppBarTheme(brightness: Brightness.dark),
          primarySwatch: Colors.blue,
          primaryColorDark: Colors.grey[300],
          accentColor: Colors.blue,
          primaryColorLight: Colors.blue,
          brightness: Brightness.light,
          // This makes the visual density adapt to the platform that you run
          // the app on. For desktop platforms, the controls will be smaller and
          // closer together (more dense) than on mobile platforms.
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
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
            : null);
  }
}
