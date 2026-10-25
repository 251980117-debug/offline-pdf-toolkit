import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';
import 'package:path/path.dart' as p;

import '../support/fake_engine.dart';
import '../support/helpers.dart';

const a4 = PageSize(595, 842);
const letter = PageSize(612, 792);
const a5 = PageSize(420, 595);
const a3 = PageSize(842, 1191);

/// Cancels the token during the second render, like a user tapping Cancel.
class _CancelOnSecondRender extends FakeEngine {
  _CancelOnSecondRender(this.token);

  final CancellationToken token;

  @override
  Future<Uint8List> renderPageAsJpeg(OpenedPdf document, int pageIndex,
      {required double scale, int jpegQuality = 85}) async {
    if (renderCalls.length == 1) token.cancel();
    return super
        .renderPageAsJpeg(document, pageIndex, scale: scale, jpegQuality: jpegQuality);
  }
}

/// Cancels the token during the third render, so two pages are already done.
class _CancelOnThirdRender extends FakeEngine {
  _CancelOnThirdRender(this.token);

  final CancellationToken token;

  @override
  Future<Uint8List> renderPageAsJpeg(OpenedPdf document, int pageIndex,
      {required double scale, int jpegQuality = 85}) async {
    if (renderCalls.length == 2) token.cancel();
    return super
        .renderPageAsJpeg(document, pageIndex, scale: scale, jpegQuality: jpegQuality);
  }
}

void main() {
  late Directory root;
  late Directory destination;
  late FakeEngine engine;
  late ImageExportService service;
  late FakeDoc source;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('opt_images_');
    destination = Directory(p.join(root.path, 'images'));
    engine = FakeEngine();
    service = ImageExportService(engine: engine);
    source = FakeDoc('src', [a4, letter, a5]);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<List<String>> names() async {
    if (!await destination.exists()) return [];
    final found = [for (final entity in await destination.list().toList()) p.basename(entity.path)];
    found.sort();
    return found;
  }

  test('names pages one-based with three digits', () {
    expect(ImageExportNaming.nameFor(0), 'page-001.jpg');
    expect(ImageExportNaming.nameFor(9), 'page-010.jpg');
    expect(ImageExportNaming.nameFor(999), 'page-1000.jpg');
  });

  test('writes one JPG per page, named in order', () async {
    final files = await service.exportPages(
        source: source, destination: destination, preset: ImageExportPreset.balanced);
    expect([for (final file in files) p.basename(file.path)],
        ['page-001.jpg', 'page-002.jpg', 'page-003.jpg']);
    expect(await names(), ['page-001.jpg', 'page-002.jpg', 'page-003.jpg']);
  });

  test('renders every page at the chosen preset', () async {
    await service.exportPages(
        source: source, destination: destination, preset: ImageExportPreset.balanced);
    expect(engine.renderCalls, hasLength(3));
    expect([for (final call in engine.renderCalls) call.pageIndex], [0, 1, 2]);
    expect(engine.renderCalls.every((c) => c.scale == ImageExportPreset.balanced.scale), isTrue);
    expect(engine.renderCalls.every((c) => c.jpegQuality == ImageExportPreset.balanced.jpegQuality),
        isTrue);
  });

  test('cancels cleanly and leaves no images behind', () async {
    final token = CancellationToken();
    final cancelService = ImageExportService(engine: _CancelOnSecondRender(token));
    await expectLater(
      cancelService.exportPages(
          source: source,
          destination: destination,
          preset: ImageExportPreset.balanced,
          cancellation: token),
      throwsEngine(EngineErrorCode.cancelled),
    );
    expect(await names(), isEmpty);
  });

  test('a failed render leaves no partial files', () async {
    engine.renderError = const EngineException(EngineErrorCode.encodeFailed, 'render failed');
    await expectLater(
      service.exportPages(
          source: source, destination: destination, preset: ImageExportPreset.high),
      throwsEngine(EngineErrorCode.encodeFailed),
    );
    expect(await names(), isEmpty);
  });

  test('never closes the source', () async {
    await service.exportPages(
        source: source, destination: destination, preset: ImageExportPreset.compact);
    expect(source.closed, isFalse);
  });

  test('a cancel during the last page still leaves nothing behind', () async {
    final token = CancellationToken();
    final cancelService = ImageExportService(engine: _CancelOnThirdRender(token));
    await expectLater(
      cancelService.exportPages(
          source: source,
          destination: destination,
          preset: ImageExportPreset.balanced,
          cancellation: token),
      throwsEngine(EngineErrorCode.cancelled),
    );
    expect(await names(), isEmpty);
  });

  test('deletes finished earlier pages when a later page fails', () async {
    final four = FakeDoc('four', [a4, letter, a5, a3]);
    final token = CancellationToken();
    final cancelService = ImageExportService(engine: _CancelOnThirdRender(token));
    await expectLater(
      cancelService.exportPages(
          source: four,
          destination: destination,
          preset: ImageExportPreset.balanced,
          cancellation: token),
      throwsEngine(EngineErrorCode.cancelled),
    );
    expect(await names(), isEmpty);
  });
}
