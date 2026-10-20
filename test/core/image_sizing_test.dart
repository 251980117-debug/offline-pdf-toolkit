import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/helpers.dart';

void main() {
  test('never upscales', () {
    expect(ImageSizing.targetPixels(const PixelSize(1000, 800), ImageQuality.balanced),
        const PixelSize(1000, 800));
  });

  test('downscales to the preset long edge, keeping aspect ratio', () {
    expect(ImageSizing.targetPixels(const PixelSize(4000, 3000), ImageQuality.compact),
        const PixelSize(1600, 1200));
    expect(ImageSizing.targetPixels(const PixelSize(3000, 6000), ImageQuality.high),
        const PixelSize(1754, 3508));
  });

  test('page matches the image aspect ratio', () {
    final landscape = ImageSizing.pageFor(const PixelSize(4000, 3000));
    expect(landscape.width, closeTo(841.89, 0.001));
    expect(landscape.height, closeTo(631.4175, 0.001));
    final portrait = ImageSizing.pageFor(const PixelSize(1000, 2000));
    expect(portrait.width, closeTo(420.945, 0.001));
    expect(portrait.height, closeTo(841.89, 0.001));
  });

  test('rejects empty and extremely narrow images', () {
    expect(() => ImageSizing.pageFor(const PixelSize(0, 10)), throwsPlan(PlanErrorCode.invalidImage));
    expect(() => ImageSizing.pageFor(const PixelSize(5100, 100)), throwsPlan(PlanErrorCode.invalidImage));
  });
}
