import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/helpers.dart';

void main() {
  test('places transparent images on white', () {
    final png = img.encodePng(img.Image(width: 8, height: 8, numChannels: 4));
    final prepared = ImagePreparer.prepareSync(png, ImageQuality.balanced);
    final jpeg = img.decodeJpg(prepared.jpegBytes)!;
    expect(jpeg.getPixel(0, 0).r, greaterThan(240));
    expect(prepared.size, const PixelSize(8, 8));
  });

  test('downscales large images', () {
    final big = img.encodeJpg(img.Image(width: 4000, height: 1000), quality: 90);
    final prepared = ImagePreparer.prepareSync(big, ImageQuality.compact);
    expect(prepared.size, const PixelSize(1600, 400));
    expect(img.decodeJpg(prepared.jpegBytes)!.width, 1600);
  });

  test('rejects files that are not images', () {
    expect(() => ImagePreparer.prepareSync(Uint8List.fromList([1, 2, 3, 4]), ImageQuality.balanced),
        throwsEngine(EngineErrorCode.unsupportedImage));
  });
}
