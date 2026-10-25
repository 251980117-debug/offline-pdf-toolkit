import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';
import 'package:path/path.dart' as p;

import '../support/fake_engine.dart';
import '../support/helpers.dart';

void main() {
  late Directory root;
  late Directory work;
  late FakeEngine engine;
  late ProcessingService service;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('opt_photo_');
    work = Directory(p.join(root.path, 'work'));
    engine = FakeEngine();
    service = ProcessingService(engine: engine, workDirectory: work);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<File> photo(String name, {int width = 1000, int height = 1400}) async {
    final file = File(p.join(root.path, name));
    await file.writeAsBytes(img.encodeJpg(img.Image(width: width, height: height), quality: 90));
    return file;
  }

  test('opens a photo as a one-page document sized to the image', () async {
    final file = await photo('IMG_0001.jpg');
    final doc = await service.openImage(file.path);
    expect(doc.pageSizes, [ImageSizing.pageFor(const PixelSize(1000, 1400))]);
    expect(engine.createdNames, ['IMG_0001.jpg']);
    await doc.close();
  });

  test('uses the quality preset when the photo is large', () async {
    final file = await photo('big.jpg', width: 4000, height: 1000);
    final doc = await service.openImage(file.path, quality: ImageQuality.compact);
    expect(doc.pageSizes, [ImageSizing.pageFor(const PixelSize(1600, 400))]);
    await doc.close();
  });

  test('rejects a file that is not an image', () async {
    final file = File(p.join(root.path, 'notes.pdf'));
    await file.writeAsBytes([1, 2, 3, 4]);
    await expectLater(
        service.openImage(file.path), throwsEngine(EngineErrorCode.unsupportedImage));
  });

  test('reads the photo once and leaves no unfinished files', () async {
    final file = await photo('one.jpg');
    final doc = await service.openImage(file.path);
    expect(engine.created.length, 1);
    expect(await work.leftovers, isEmpty);
    await doc.close();
  });
}

extension on Directory {
  Future<List<String>> get leftovers async {
    if (!await exists()) return [];
    return [for (final e in await list().toList()) p.basename(e.path)];
  }
}
