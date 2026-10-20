import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:offline_pdf_toolkit/engine/pdfrx_engine.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

/// Milestone 1 gate. Run on a real Android phone and a real iPhone with
/// airplane mode ON:
///   flutter test integration_test/engine_validation_test.dart -d `<device>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = PdfrxEngine();
  final opened = <OpenedPdf>[];
  late Directory root;
  late ProcessingService service;

  setUpAll(PdfrxEngine.initialize);

  setUp(() async {
    root = await Directory.systemTemp.createTemp('opt_validation_');
    service = ProcessingService(engine: engine, workDirectory: Directory(p.join(root.path, 'work')));
  });

  tearDown(() async {
    for (final doc in opened) {
      await doc.close();
    }
    opened.clear();
    await root.delete(recursive: true);
  });

  Future<String> fixture(String name) async {
    final data = await rootBundle.load('assets/validation/$name');
    final file = File(p.join(root.path, name));
    await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
    return file.path;
  }

  Future<OpenedPdf> open(String path, {String? password}) async {
    final doc = await service.open(path, password: password);
    opened.add(doc);
    return doc;
  }

  File out(String name) => File(p.join(root.path, 'out', name));

  Future<List<String>> pageTexts(File file) async {
    final doc = await pdfrx.PdfDocument.openFile(file.path);
    try {
      return [for (final page in doc.pages) ((await page.loadText())?.fullText ?? '').trim()];
    } finally {
      await Future.sync(doc.dispose);
    }
  }

  Future<WriteResult> write(PagePlan plan, List<OpenedPdf> docs, String name,
          {bool allowUnprotect = false}) =>
      service.writePlan(
        plan: plan,
        sources: {for (final d in docs) d.id: d},
        destination: out(name),
        allowRemovingPasswordProtection: allowUnprotect,
      );

  testWidgets('merge keeps every page in order, keeps text, and leaves originals unchanged', (_) async {
    final alphaPath = await fixture('alpha_3_pages.pdf');
    final before = await File(alphaPath).readAsBytes();
    final alpha = await open(alphaPath);
    final bravo = await open(await fixture('bravo_2_pages.pdf'));
    final result = await write(PageOperations.merge([alpha.toSource(), bravo.toSource()]), [alpha, bravo], 'merged.pdf');
    expect(result.pageCount, 5);
    expect(await pageTexts(result.file),
        ['Alpha page 1', 'Alpha page 2', 'Alpha page 3', 'Bravo page 1', 'Bravo page 2']);
    expect(await File(alphaPath).readAsBytes(), before);
  });

  testWidgets('extract, delete and reorder produce the expected pages', (_) async {
    final alpha = await open(await fixture('alpha_3_pages.pdf'));
    final source = alpha.toSource();
    final extracted = await write(PageOperations.extract(source, [2, 0]), [alpha], 'extract.pdf');
    expect(await pageTexts(extracted.file), ['Alpha page 1', 'Alpha page 3']);
    final deleted = await write(PageOperations.deletePages(source, [1]), [alpha], 'delete.pdf');
    expect(await pageTexts(deleted.file), ['Alpha page 1', 'Alpha page 3']);
    final reordered = await write(PageOperations.reorder(source, [2, 0, 1]), [alpha], 'reorder.pdf');
    expect(await pageTexts(reordered.file), ['Alpha page 3', 'Alpha page 1', 'Alpha page 2']);
  });

  testWidgets('rotation is applied only to the selected page', (_) async {
    final alpha = await open(await fixture('alpha_3_pages.pdf'));
    final plan = PageOperations.wholeDocument(alpha.toSource()).rotatePositions([0], QuarterTurn.clockwise90);
    final result = await write(plan, [alpha], 'rotate.pdf');
    final doc = await pdfrx.PdfDocument.openFile(result.file.path);
    try {
      expect(doc.pages[0].rotation, pdfrx.PdfPageRotation.clockwise90);
      expect(doc.pages[1].rotation, pdfrx.PdfPageRotation.none);
    } finally {
      await Future.sync(doc.dispose);
    }
    expect((await pageTexts(result.file)).first, 'Alpha page 1');
  });

  testWidgets('split creates one correct file per part', (_) async {
    final alpha = await open(await fixture('alpha_3_pages.pdf'));
    final parts = PageOperations.splitEvery(alpha.toSource(), 1);
    for (var i = 0; i < parts.length; i++) {
      final result = await write(parts[i], [alpha], 'part$i.pdf');
      expect(await pageTexts(result.file), ['Alpha page ${i + 1}']);
    }
  });

  testWidgets('images become pages with the right shape', (_) async {
    final png = img.encodePng(img.Image(width: 3000, height: 2000));
    final prepared = await ImagePreparer.prepare(png, ImageQuality.balanced);
    final result = await service.imagesToPdf(images: [prepared], destination: out('image.pdf'));
    expect(result.pageCount, 1);
    final sizes = await engine.readPageSizes(await result.file.readAsBytes());
    expect(sizes.single.matchesIgnoringRotation(ImageSizing.pageFor(prepared.size)), isTrue);
  });

  testWidgets('password-protected files are handled explicitly', (_) async {
    final path = await fixture('alpha_protected.pdf');
    await expectLater(service.open(path), throwsA(isA<EngineException>()
        .having((e) => e.code, 'code', EngineErrorCode.passwordRequired)));
    await expectLater(service.open(path, password: 'wrong'), throwsA(isA<EngineException>()
        .having((e) => e.code, 'code', EngineErrorCode.wrongPassword)));
    final locked = await open(path, password: 'fixture-pass');
    expect(locked.wasPasswordProtected, isTrue);
    final plan = PageOperations.wholeDocument(locked.toSource());
    await expectLater(write(plan, [locked], 'locked.pdf'), throwsA(isA<EngineException>()
        .having((e) => e.code, 'code', EngineErrorCode.protectionWouldBeRemoved)));
    final result = await write(plan, [locked], 'unlocked.pdf', allowUnprotect: true);
    expect(await pageTexts(result.file), ['Alpha page 1', 'Alpha page 2', 'Alpha page 3']);
  });

  testWidgets('large document benchmark: 300 pages', (_) async {
    final alpha = await open(await fixture('alpha_3_pages.pdf'));
    final plan = PagePlan([for (var i = 0; i < 300; i++) PageRef(alpha.id, i % 3)]);
    final watch = Stopwatch()..start();
    final result = await write(plan, [alpha], 'large.pdf');
    // ignore: avoid_print
    print('300 pages: ${watch.elapsedMilliseconds} ms, ${result.byteLength} bytes');
    expect(result.pageCount, 300);
  });
}
