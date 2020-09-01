import 'apiWrapperStub.dart'
    if (dart.library.io) 'androidApiWrapper.dart'
    if (dart.library.html) 'webApiWrapper.dart';

class AppSettings {
  static Map files;
  APIWrapper api;
  static String filesTheme = 'new';
  static String fabTheme = 'extended';

  AppSettings() {
    api = APIWrapper();
  }

  Future<void> getSettings() async {
    fabTheme = await api.getString('fabTheme', 'extended');
    filesTheme = await api.getString('filesTheme', 'new');
  }

  Future<Map<String, dynamic>> getFiles() async {
    if (files == null) {
      files = await api.getFiles();
    }
    return files;
  }

  Future<bool> saveFiles() async {
    if (files == null) return false;
    return await api.saveFiles(files);
  }

  Future<bool> saveSettings() async {
    api.saveString('fabTheme', fabTheme);
    api.saveString('filesTheme', filesTheme);
  }
}
