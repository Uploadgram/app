// ignore: avoid_web_libraries_in_flutter
import 'dart:html';

import 'package:flutter/cupertino.dart';
import 'package:uploadgram/widgets/platform_specific/uploaded_file_thumbnail/common.dart';

class UploadedFileThumbnail extends StatelessWidget {
  final String fileId;
  final bool fullImageSize;
  final IconData defaultIcon;
  final double? defaultIconSize;
  final Color? defaultIconColor;
  final File? file;

  UploadedFileThumbnail({
    required this.fileId,
    required this.defaultIcon,
    this.defaultIconSize,
    this.defaultIconColor,
    this.fullImageSize = false,
    this.file,
  }) : assert(fileId.length == 49 || fileId.length == 48);

  static Future<void> generateThumbs(String fileId, File? file) async => null;
  static Future<void> deleteThumbs(String fileId) async => null;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      defaultIcon,
      size: defaultIconSize,
      color: defaultIconColor,
    );
    return fallback;
  }
}

class ThumbnailsUtils {
  static Future<ThumbnailsStats> getThumbnailsStats() async =>
      ThumbnailsStats(smallThumbsCount: 0, smallThumbsSize: 0);
}
