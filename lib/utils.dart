String humanSize(double bytes) {
  List<String> sizes = ["B", "KB", "MB", "GB"];
  int i = 0;
  while (bytes > 1000) {
    bytes /= 1000;
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
