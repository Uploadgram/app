import 'apiWrapperStub.dart'
    if (dart.library.io) 'androidApiWrapper.dart'
    if (dart.library.html) 'webApiWrapper.dart';

class AppSettings {
  static Map files;
  static APIWrapper api = APIWrapper();
  static String filesTheme = 'new';
  static String fabTheme = 'extended';

  static Future<bool> copy(
    String text,
  ) =>
      api.copy(text);

  static Future<void> getSettings() async {
    fabTheme = await api.getString('fabTheme', 'extended');
    filesTheme = await api.getString('filesTheme', 'new');
  }

  static Future<Map<String, dynamic>> getFiles() async {
    if (files == null) {
      files = await api.getFiles();
    }
    return files;
  }

  static Future<bool> saveFiles() async {
    if (files == null) return false;
    return await api.saveFiles(files);
  }

  static Future<bool> saveSettings() async {
    return await api.saveString('fabTheme', fabTheme) &&
        await api.saveString('filesTheme', filesTheme);
  }
}
