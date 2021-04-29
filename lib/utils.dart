import 'dart:convert';

import 'package:uploadgram/app_logic.dart';

class Utils {
  static String humanSize(int bytes) {
    double tmp = bytes.toDouble();
    List<String> sizes = ["B", "KB", "MB", "GB"];
    int i = 0;
    while (tmp > 1000) {
      tmp /= 1000;
      if (++i >= (sizes.length - 1)) break;
    }
    return tmp.toStringAsFixed(2) + ' ' + sizes[i];
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

  static Future<Map<String, dynamic>?> parseFragment(String fragment) async {
    Map<String, dynamic> files = {};
    if (fragment.indexOf('import:') == 0) {
      fragment = fragment.substring(7);
      if (fragment.substring(0, 1) == '{') {
        try {
          var parsedFiles = json.decode(fragment);
          if (parsedFiles is! Map) return {};

          parsedFiles.cast<String, dynamic>().forEach((String key, value) {
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

  static int getUploadedDate(String url) =>
      int.parse(url.split('/').last.substring(0, 8), radix: 16);
}
