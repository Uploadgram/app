import 'package:uploadgram/app_logic.dart';
import 'package:uploadgram/app_definitions.dart';

class AppSettings {
  static FilesTheme? filesTheme;
  static FabTheme? fabTheme;
  static Themes? appTheme;
  static bool error = false;

  static Future<void> getSettings() async {
    String? fabThemeString = await AppLogic.platformApi
        .getString('fabTheme', FabTheme.centerExtended.toString());
    String? filesThemeString = await AppLogic.platformApi
        .getString('filesTheme', FilesTheme.grid.toString());
    filesTheme = FilesTheme.values.firstWhere(
        (element) => element.toString() == filesThemeString,
        orElse: () => FilesTheme.grid);
    fabTheme = FabTheme.values.firstWhere(
        (element) => element.toString() == fabThemeString,
        orElse: () => FabTheme.centerExtended);
    String? appThemeString = await AppLogic.platformApi
        .getString('appTheme', Themes.system.toString());
    appTheme = Themes.values.firstWhere(
        (element) => element.toString() == appThemeString,
        orElse: () => Themes.dark);
  }

  static Future<bool> saveSettings() async {
    if (fabTheme == null || filesTheme == null) return false;
    return await AppLogic.platformApi
            .setString('fabTheme', fabTheme!.toString()) &&
        await AppLogic.platformApi
            .setString('filesTheme', filesTheme!.toString()) &&
        await AppLogic.platformApi.setString('appTheme', appTheme!.toString());
  }
}
