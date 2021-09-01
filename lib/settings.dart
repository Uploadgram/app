import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:uploadgram/api_definitions.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:hive/hive.dart';
import 'package:uploadgram/config.dart';
import 'package:uploadgram/internal_api_wrapper/platform_instance.dart';
import 'package:hive_box_generator/hive_box_generator.dart';

part 'settings.g.dart';

@HiveBox(boxName: 'settings')
abstract class Settings {
  @HiveBoxField(defaultValue: Themes.system)
  late Themes appTheme;
  @HiveBoxField(defaultValue: FabTheme.centerExtended)
  late FabTheme fabTheme;
  @HiveBoxField(defaultValue: FilesTheme.grid)
  late FilesTheme filesTheme;
  @HiveBoxField(defaultValue: false)
  late bool saveFullSizedImages;
  @HiveBoxField(defaultValue: false)
  late bool tosAccepted;
  @HiveBoxField(defaultValue: 200)
  late int smallThumbnailSize;
  @HiveBoxField(
      defaultValue:
          SortOptions(sortType: SortType.descending, sortBy: SortBy.uploadDate))
  late SortOptions preferredSortOptions;
  @HiveBoxField(defaultValue: true)
  late bool shouldGenerateThumbnails;
  @HiveBoxField(defaultValue: defaultEndpoint)
  late Endpoint? endpoint;
  @HiveBoxField(defaultValue: null)
  late Locale? locale;
  @HiveBoxField(defaultValue: Colors.blue)
  late Color accent;
  @HiveBoxField(defaultValue: false)
  late bool syncAccentWithSystem;
  @HiveBoxField(defaultValue: false)
  late bool hasAskedApp;

  static final _$SettingsInstance _instance = _$SettingsInstance();

  static Color? _systemAccent;
  static Future<void> updateAccent() async {
    _systemAccent = null;
    if (InternalAPIWrapper.isAndroid && _instance.syncAccentWithSystem) {
      _systemAccent = await InternalAPIWrapper().getAccent();
    }
  }

  /// If [syncAccentWithSystem] is true, it will try to get the system accent if on Android,
  /// otherwise it will return the set accent, and if there ain't none,
  /// it will just return the default one.
  static Color get themeAccent {
    if (_systemAccent != null) return _systemAccent!;

    return _instance.accent;
  }

  Future<void> init() => updateAccent();
  Future<void> close() async {}
}

class ColorAdapter extends TypeAdapter<Color> {
  @override
  int get typeId => 10;

  @override
  void write(BinaryWriter writer, Color obj) => writer.writeInt(obj.value);

  @override
  Color read(BinaryReader reader) => Color(reader.readInt());
}

class LocaleAdapter extends TypeAdapter<Locale> {
  @override
  int get typeId => 11;

  @override
  void write(BinaryWriter writer, Locale obj) {
    writer.writeByte(1);
    writer.writeString(obj.languageCode);
    if (obj.scriptCode != null && obj.scriptCode!.isNotEmpty) {
      writer.writeByte(2);
      writer.writeString(obj.scriptCode!);
    }
    if (obj.countryCode != null && obj.countryCode!.isNotEmpty) {
      writer.writeByte(3);
      writer.writeString(obj.countryCode!);
    }
    writer.writeByte(0);
  }

  @override
  Locale read(BinaryReader reader) {
    final fields = <int, String>{};
    int byte;
    int i = 0;
    while (0 != (byte = reader.readByte())) {
      if (++i > 3) throw Exception('Looped over three times.');
      fields[byte] = reader.readString();
    }
    return Locale.fromSubtags(
        languageCode: fields[1]!,
        scriptCode: fields[2],
        countryCode: fields[3]);
  }
}

/// Settings constant
final settings = Settings._instance;
