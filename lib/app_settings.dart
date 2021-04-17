import 'package:uploadgram/app_logic.dart';

class AppSettings {
  static String? filesTheme;
  static String? fabTheme;
  static bool error = false;

  static Future<void> getSettings() async {
    fabTheme = await AppLogic.platformApi.getString('fabTheme', 'extended');
    filesTheme = await AppLogic.platformApi.getString('filesTheme', 'new');
  }

  static Future<bool> saveSettings() async {
    if (fabTheme == null || filesTheme == null) return false;
    return await AppLogic.platformApi.setString('fabTheme', fabTheme!) &&
        await AppLogic.platformApi.setString('filesTheme', filesTheme!);
  }
}
