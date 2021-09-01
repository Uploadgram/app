import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/web_api_wrapper/platform_instance.dart';

class Utils {
  static final _logger = Logger('Utils');

  /// Converts [bytes] in a human-readable string like "8 KB", "10 MB" and so on
  static String humanSize(int bytes) {
    double tmp = bytes.toDouble();
    List<String> sizes = ["B", "KB", "MB", "GB"];
    int i;
    for (i = 0; tmp > 1000 && i < (sizes.length - 1); ++i) {
      tmp /= 1000;
    }

    return tmp.toStringAsFixed(2) + ' ' + sizes[i];
  }

  /// Parses the file's name and cleans it before a rename.
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
    for (var char in unallowedChars) {
      name.replaceAll(char, '_');
    }
    return name;
  }

  /// Parses the fragment, which is used by the Uploadgram bot to import the file in the app.
  static Future<Map<String, dynamic>?> parseFragment(String fragment) async {
    Map<String, dynamic> files = {};
    _logger.info('importing from fragment "$fragment"');
    if (fragment.indexOf('import:') == 0) {
      fragment = fragment.substring(7);
      if (fragment.substring(0, 1) == '{') {
        try {
          var parsedFiles = json.decode(fragment);
          if (parsedFiles is! Map) return null;

          parsedFiles.cast<String, dynamic>().forEach((String key, value) {
            if (key.length == 48 || key.length == 49) {
              files[key] = value;
            }
          });
        } catch (e) {
          return null;
        }
      } else {
        if (fragment.length == 48 || fragment.length == 49) {
          _logger.info('trying new import method...');
          Map? file = await WebAPIWrapper().getFile(fragment);
          if (file != null) {
            file.remove('mime');
            files[fragment] = file;
          }
        }
      }
      return files;
    }
  }

  /// Gets when the file was uploaded, based on the file's url.
  static int getUploadedDate(String url) =>
      int.parse(url.split('/').lastEntry.substring(0, 8), radix: 16);

  /// Will get the text between [from] and [to] in [source]
  static String getTextInBetween(String source, String from, String to,
      {int start = 0}) {
    final first = source.indexOf(from, 0);
    final last = source.indexOf(to, first + from.length);
    return source.substring(first + from.length, last - to.length + 1);
  }
}
