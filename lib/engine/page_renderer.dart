import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'engine_exception.dart';

/// Raw pixels from a rendered page: one byte per channel, row-major, top-left
/// first. [channels] is 3 for RGB or 4 for BGRA, the layout PDFium renders.
class RenderedPixels {
  const RenderedPixels({
    required this.pixels,
    required this.width,
    required this.height,
    required this.channels,
  });

  final Uint8List pixels;
  final int width;
  final int height;
  final int channels;
}

/// Turns raw rendered pixels into JPEG bytes on a white background.
abstract final class PageRenderer {
  /// Composes [frame] on white (transparent or alpha pixels must not become
  /// black) and encodes it as a JPEG. Returns null when the frame has no
  /// pixels. Never resizes: the caller decides the render scale.
  static Uint8List? encodeJpeg(RenderedPixels frame, {int quality = 85}) {
    if (frame.pixels.isEmpty || frame.width <= 0 || frame.height <= 0) {
      return null;
    }
    if (frame.pixels.length < frame.width * frame.height * frame.channels) {
      throw const EngineException(EngineErrorCode.encodeFailed,
          'The rendered page was incomplete.');
    }
    // 4 channels arrive as BGRA, matching what pdfrx hands back.
    final image = img.Image.fromBytes(
      width: frame.width,
      height: frame.height,
      bytes: frame.pixels.buffer,
      bytesOffset: frame.pixels.offsetInBytes,
      numChannels: frame.channels,
      order:
          frame.channels == 4 ? img.ChannelOrder.bgra : img.ChannelOrder.rgb,
    );
    if (image.numChannels == 4) {
      // JPEG has no transparency: place the image on white, not black.
      final canvas = img.Image(width: image.width, height: image.height);
      img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(canvas, image);
      return img.encodeJpg(canvas, quality: quality);
    }
    return img.encodeJpg(image, quality: quality);
  }
}
