import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../core/image_sizing.dart';
import '../core/page_size.dart';
import 'engine_exception.dart';

class PreparedImage {
  const PreparedImage({required this.jpegBytes, required this.size});

  final Uint8List jpegBytes;
  final PixelSize size;
}

/// Decodes, fixes camera orientation, downscales and re-encodes an image
/// as JPEG. Runs off the UI thread.
abstract final class ImagePreparer {
  static Future<PreparedImage> prepare(Uint8List bytes, ImageQuality quality) =>
      Isolate.run(() => prepareSync(bytes, quality));

  static PreparedImage prepareSync(Uint8List bytes, ImageQuality quality) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const EngineException(EngineErrorCode.unsupportedImage,
          'This image format is not supported. Use JPEG or PNG.');
    }
    var image = img.bakeOrientation(decoded);
    final target =
        ImageSizing.targetPixels(PixelSize(image.width, image.height), quality);
    if (target.width != image.width || target.height != image.height) {
      image = img.copyResize(image,
          width: target.width,
          height: target.height,
          interpolation: img.Interpolation.average);
    }
    if (image.numChannels == 4) {
      // JPEG has no transparency: place the image on white, not black.
      final canvas = img.Image(width: image.width, height: image.height);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, image);
      image = canvas;
    }
    return PreparedImage(
      jpegBytes: img.encodeJpg(image, quality: quality.jpegQuality),
      size: PixelSize(image.width, image.height),
    );
  }

  /// A plain white page as JPEG bytes, so a blank page can be inserted into a
  /// document like any other one-page file.
  static Uint8List blankJpeg(PageSize size, {int dpi = 150}) {
    final width = (size.width / 72 * dpi).round().clamp(1, 20000);
    final height = (size.height / 72 * dpi).round().clamp(1, 20000);
    final canvas = img.Image(width: width, height: height);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    return img.encodeJpg(canvas, quality: 85);
  }
}
