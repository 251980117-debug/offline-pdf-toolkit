import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';
import 'package:path/path.dart' as p;

import '../support/fake_engine.dart';

void main() {
  test('makes a white page the size of A4', () {
    final decoded = img.decodeJpg(ImagePreparer.blankJpeg(PageSize.a4))!;
    // 150 dpi over A4 points: 595.28/72*150 and 841.89/72*150.
    expect(decoded.width, 1240);
    expect(decoded.height, 1754);
    final pixel = decoded.getPixel(10, 10);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('opens a blank page as a one-page A4 document', () async {
    final root = await Directory.systemTemp.createTemp('opt_blank_');
    addTearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });
    final engine = FakeEngine();
    final service = ProcessingService(
        engine: engine, workDirectory: Directory(p.join(root.path, 'work')));

    final doc = await service.blankPage();

    expect(doc.pageSizes, [PageSize.a4]);
    expect(engine.createdNames, ['Blank page']);
    await doc.close();
  });
}
