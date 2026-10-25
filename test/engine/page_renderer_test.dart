import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/fake_engine.dart';
import '../support/helpers.dart';

void main() {
  test('places transparent pixels on white', () {
    // BGRA, fully transparent: it must not become black.
    final pixels = Uint8List.fromList([10, 20, 30, 0]);
    final jpeg = PageRenderer.encodeJpeg(
        RenderedPixels(pixels: pixels, width: 1, height: 1, channels: 4))!;
    final p = img.decodeJpg(jpeg)!.getPixel(0, 0);
    expect(p.r, greaterThan(240));
    expect(p.g, greaterThan(240));
    expect(p.b, greaterThan(240));
  });

  test('keeps the requested dimensions', () {
    final pixels = Uint8List(40 * 20 * 3);
    final jpeg = PageRenderer.encodeJpeg(
        RenderedPixels(pixels: pixels, width: 40, height: 20, channels: 3))!;
    final decoded = img.decodeJpg(jpeg)!;
    expect(decoded.width, 40);
    expect(decoded.height, 20);
  });

  test('returns null when there are no pixels', () {
    expect(
      PageRenderer.encodeJpeg(
          RenderedPixels(pixels: Uint8List(0), width: 0, height: 0, channels: 4)),
      isNull,
    );
  });

  test('reads 4 channels as BGRA, the layout pdfrx renders', () {
    // Pure blue in BGRA order must come out blue, not red.
    final pixels = Uint8List.fromList([255, 0, 0, 255]);
    final jpeg = PageRenderer.encodeJpeg(
        RenderedPixels(pixels: pixels, width: 1, height: 1, channels: 4))!;
    final p = img.decodeJpg(jpeg)!.getPixel(0, 0);
    expect(p.b, greaterThan(240));
    expect(p.r, lessThan(60));
  });

  test('the fake engine records renders and returns deterministic bytes',
      () async {
    final engine = FakeEngine();
    final doc = FakeDoc('doc-1', const [PageSize(595, 842)]);

    final bytes =
        await engine.renderPageAsJpeg(doc, 0, scale: 1.5, jpegQuality: 70);

    expect(utf8.decode(bytes), 'FAKEJPEG:doc-1:0:1.5');
    final call = engine.renderCalls.single;
    expect(call.documentId, 'doc-1');
    expect(call.pageIndex, 0);
    expect(call.scale, 1.5);
    expect(call.jpegQuality, 70);
  });

  test('the fake engine can fail a render on purpose', () async {
    final engine = FakeEngine()
      ..renderError =
          const EngineException(EngineErrorCode.encodeFailed, 'boom');
    final doc = FakeDoc('doc-1', const [PageSize(595, 842)]);

    await expectLater(engine.renderPageAsJpeg(doc, 0, scale: 1),
        throwsEngine(EngineErrorCode.encodeFailed));
  });
}
