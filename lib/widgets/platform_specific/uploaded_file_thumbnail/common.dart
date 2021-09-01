import 'package:image/image.dart' as flt_image;
import 'package:uploadgram/app_definitions.dart';
import 'package:uploadgram/settings.dart';

abstract class ThumbnailGeneratorData {
  final String? url;
  final ThumbnailDataImpl thumbnailsData;
  final int finalImageSize;
  get file;

  ThumbnailGeneratorData({
    required this.thumbnailsData,
    this.finalImageSize = 200,
    this.url,
  });
}

abstract class ThumbnailDataImpl {
  get thumbFull;
  get thumbSmall;
}

Future<List<int>?> generateThumbnail(
    List<int> imageBytes, int finalImageSize) async {
  final image = flt_image.decodeImage(imageBytes);
  if (image == null) {
    return null;
  }
  if (image.width <= finalImageSize && image.height <= finalImageSize) {
    return flt_image.encodePng(image);
  } // in case the image is smaller than the finalImageSize, don't resize it
  final bool isLarger = image.width > image.height;
  final flt_image.Image resizedImage = flt_image.copyResize(image,
      width: isLarger ? null : finalImageSize,
      height: isLarger ? finalImageSize : null);
  final flt_image.Image finalImage = flt_image.copyCrop(
    resizedImage,
    isLarger ? (resizedImage.width / 2 - finalImageSize / 2).toInt() : 0,
    isLarger ? 0 : (resizedImage.height / 2 - finalImageSize / 2).toInt(),
    finalImageSize,
    finalImageSize,
  );
  return flt_image.encodePng(finalImage);
}

const allowedExtensions = ['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'];

bool canGenerateThumbnail(int size, String name) {
  if (!settings.shouldGenerateThumbnails) return false;
  if (size > 5000000) return false;
  if (!allowedExtensions.contains(extension(name))) return false;
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
