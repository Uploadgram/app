import 'package:uploadgram/app_definitions.dart';
import 'package:hive/hive.dart';

class AppSettings {
  static late Box _settingsBox;

  static Future<void> getSettings() async {
    _settingsBox = await Hive.openBox('settings');
  }

  static Themes get appTheme =>
      Themes.values[_settingsBox.get('theme', defaultValue: 0) as int];
  static set appTheme(Themes value) => _settingsBox.put('theme', value.index);

  static FabTheme get fabTheme => FabTheme.values[get('fabTheme', 0) as int];
  static set fabTheme(FabTheme value) => put('fabTheme', value.index);

  static FilesTheme get filesTheme =>
      FilesTheme.values[get('filesTheme', 0) as int];
  static set filesTheme(FilesTheme value) => put('filesTheme', value.index);

  static bool get saveFullSizedImages => get('saveFullSizedImage', false);
  static set saveFullSizedImages(bool value) =>
      put('saveFullSizedImage', value);

  static bool get tosAccepted => get('tosAccepted', false);
  static set tosAccepted(bool value) => _settingsBox.put('tosAccepted', value);
  static int get smallThumbnailSize => get('smallThumbnailSize', 200);
  static set smallThumbnailSize(int value) => put('smallThumbnailSize', value);
  static SortOptions get preferredSortOptions => SortOptions(
      sortBy: SortBy.values[get('lastSortBy', 0)],
      sortType: SortType.values[get('lastSortType', 0)]);
  static set preferredSortOptions(SortOptions options) {
    put('lastSortBy', options.sortBy.index);
    put('lastSortType', options.sortType.index);
  }

  static bool get shouldGenerateThumbnails =>
      get('shouldGenerateThumbnails', false);
  static set shouldGenerateThumbnails(bool value) =>
      put('shouldGenerateThumbnails', value);

  static get(String key, [dynamic? defaultValue]) =>
      _settingsBox.get(key, defaultValue: defaultValue);
  static put(String key, dynamic value) => _settingsBox.put(key, value);
}
