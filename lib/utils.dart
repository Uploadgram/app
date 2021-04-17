import 'dart:convert';

import 'package:uploadgram/app_logic.dart';

class Utils {
  static String humanSize(double bytes) {
    List<String> sizes = ["B", "KB", "MB", "GB"];
    int i = 0;
    while (bytes > 1000) {
      bytes /= 1000;
      if (++i >= (sizes.length - 1)) break;
    }
    return bytes.toStringAsFixed(2) + ' ' + sizes[i];
  }

  static Future<String> parseName(String name) async {
    List<String> unallowedChars = [
      '/',
      '<',
      '>',
      '"',
      ':',
      '\\',
      '|',
      '?',
      '*',
      '\n',
      '\t',
      '\r'
    ];
    unallowedChars.forEach((char) => name.replaceAll(char, '_'));
    return name;
  }

  static Future<Map?> parseFragment(String fragment) async {
    Map files = {};
    if (fragment.indexOf('import:') == 0) {
      fragment = fragment.substring(7);
      print(fragment);
      if (fragment.substring(0, 1) == '{') {
        try {
          Map parsedFiles = json.decode(fragment);
          parsedFiles.forEach((key, value) {
            if (key.length == 48 || key.length == 49) {
              files[key] = value;
            }
          });
        } catch (e) {}
      } else {
        if (fragment.length == 48 || fragment.length == 49) {
          print('trying new import method...');
          Map? file = await AppLogic.webApi.getFile(fragment);
          if (file != null) {
            file.remove('mime');
            files[fragment] = file;
          }
        }
      }
      return files;
    }
  }
}
