import 'package:image/image.dart' as fltImage;
import 'package:uploadgram/app_settings.dart';
import 'package:uploadgram/mime_types.dart';

abstract class ThumbnailGeneratorData {
  final String? url;
  final ThumbnailData thumbnailsData;
  final int finalImageSize;
  get file;

  ThumbnailGeneratorData({
    required this.thumbnailsData,
    this.finalImageSize = 200,
    this.url,
  });
}

abstract class ThumbnailData {
  get thumbFull;
  get thumbSmall;
}

Future<List<int>?> generateThumbnail(
    List<int> imageBytes, int finalImageSize) async {
  final image = fltImage.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  if (image.width < finalImageSize || image.height < finalImageSize)
    return fltImage.encodePng(
        image); // in case the image is smaller than the finalImageSize, don't resize it
  final bool isLarger = image.width > image.height;
  final fltImage.Image resizedImage = fltImage.copyResize(image,
      width: isLarger ? null : finalImageSize,
      height: isLarger ? finalImageSize : null);
  final fltImage.Image finalImage = fltImage.copyCrop(
    resizedImage,
    isLarger ? (resizedImage.width / 2 - finalImageSize / 2).toInt() : 0,
    isLarger ? 0 : (resizedImage.height / 2 - finalImageSize / 2).toInt(),
    finalImageSize,
    finalImageSize,
  );
  return fltImage.encodePng(finalImage);
}

bool canGenerateThumbnail(int size, String name) {
  if (!AppSettings.shouldGenerateThumbnails) return false;
  if (size > 5000000) return false;
  if (mimeTypes[name.split('.').last]?.type != 'image') return false;
  return true;
}

class ThumbnailsStats {
  final int? smallThumbsSize;
  final int? smallThumbsCount;
  final int? bigThumbsSize;
  final int? bigThumbsCount;

  ThumbnailsStats({
    this.smallThumbsCount,
    this.smallThumbsSize,
    this.bigThumbsCount,
    this.bigThumbsSize,
  });
}
