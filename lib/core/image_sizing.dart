import 'dart:math';

import 'page_size.dart';
import 'plan_exception.dart';

/// Image-to-PDF quality presets. This is the only size control in version 1.
enum ImageQuality {
  compact(maxLongEdgePx: 1600, jpegQuality: 70),
  balanced(maxLongEdgePx: 2480, jpegQuality: 82),
  high(maxLongEdgePx: 3508, jpegQuality: 92);

  const ImageQuality({required this.maxLongEdgePx, required this.jpegQuality});

  final int maxLongEdgePx;
  final int jpegQuality;
}

class PixelSize {
  const PixelSize(this.width, this.height);

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is PixelSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'PixelSize($width x $height)';
}

abstract final class ImageSizing {
  /// Long edge of an A4 page in points.
  static const double a4LongEdgePt = 841.89;
  static const double maxAspectRatio = 50;

  /// Downscales so the long edge fits the preset. Never upscales.
  static PixelSize targetPixels(PixelSize source, ImageQuality quality) {
    _check(source);
    final longEdge = max(source.width, source.height);
    if (longEdge <= quality.maxLongEdgePx) return source;
    final scale = quality.maxLongEdgePx / longEdge;
    return PixelSize(max(1, (source.width * scale).round()),
        max(1, (source.height * scale).round()));
  }

  /// A page with the image's exact aspect ratio, so nothing is cropped
  /// or stretched.
  static PageSize pageFor(PixelSize image, {double longEdgePt = a4LongEdgePt}) {
    _check(image);
    if (image.width >= image.height) {
      return PageSize(longEdgePt, longEdgePt * image.height / image.width);
    }
    return PageSize(longEdgePt * image.width / image.height, longEdgePt);
  }

  static void _check(PixelSize size) {
    if (size.width < 1 || size.height < 1) {
      throw const PlanException(
          PlanErrorCode.invalidImage, 'The image has no visible pixels.');
    }
    final ratio = max(size.width, size.height) / min(size.width, size.height);
    if (ratio > maxAspectRatio) {
      throw const PlanException(PlanErrorCode.invalidImage,
          'This image is too long and narrow to place on a page.');
    }
  }
}
