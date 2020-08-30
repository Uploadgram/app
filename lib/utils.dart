import 'package:http_parser/http_parser.dart';

Map<String, MediaType> mimeTypes = {
  'bmp': MediaType('image', 'bmp'),
  'gif': MediaType('image', 'gif'),
  'ico': MediaType('image', 'vnd.microsoft.icon'),
  'svg': MediaType('image', 'svg+xml'),
  'tiff': MediaType('image', 'tiff'),
  'tif': MediaType('image', 'tiff'),
  'webp': MediaType('image', 'webp'),
  'png': MediaType('image', 'png'),
  'jpeg': MediaType('image', 'jpeg'),
  'jpg': MediaType('image', 'jpeg'),
  'mp3': MediaType('audio', 'mpeg'),
  'aac': MediaType('audio', 'aac'),
  'mid': MediaType('audio', 'midi'),
  'midi': MediaType('audio', 'midi'),
  'oga': MediaType('audio', 'ogg'),
  'wav': MediaType('audio', 'wav'),
  'weba': MediaType('audio', 'webm'),
  'opus': MediaType('audio', 'opus'),
  'mpeg': MediaType('video', 'mpeg'),
  'avi': MediaType('video', 'x-msvideo'),
  'ogv': MediaType('video', 'ogg'),
  'ts': MediaType('video', 'mp2t'),
  'webm': MediaType('video', 'webm'),
  'txt': MediaType('text', 'plain'),
  'pdf': MediaType('application', 'pdf'),
  'json': MediaType('application', 'json'),
  'jsonld': MediaType('application', 'json+ld'),
};

String humanSize(double bytes) {
  List<String> sizes = ["B", "KB", "MB", "GB"];
  int i = 0;
  while (bytes > 1024) {
    bytes /= 1024;
    if (++i >= (sizes.length - 1)) break;
  }
  return bytes.toStringAsFixed(2) + ' ' + sizes[i];
}

Future<String> parseName(String name) async {
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
