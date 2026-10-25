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

/// Cancels the token on the second page, like a user tapping Cancel.
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

void main() {
  late Directory root;
  late Directory work;
  late FakeEngine engine;
  late ProcessingService service;
  late FakeDoc source;
  late String sourcePath;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('opt_compress_');
    work = Directory(p.join(root.path, 'work'));
    engine = FakeEngine();
    service = ProcessingService(engine: engine, workDirectory: work);
    source = FakeDoc('src', [a4, letter, a5]);
    sourcePath = p.join(root.path, 'source.pdf');
    await File(sourcePath).writeAsString('ORIGINAL');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File out(String name) => File(p.join(root.path, 'out', name));

  Future<List<String>> leftovers() async {
    if (!await work.exists()) return [];
    return [for (final entity in await work.list().toList()) p.basename(entity.path)];
  }

  test('renders every page at the chosen level', () async {
    final result = await service.compress(
      source: source,
      level: CompressLevel.balanced,
      destination: out('c.pdf'),
      sourcePath: sourcePath,
    );
    expect(result.pageCount, 3);
    expect(engine.renderCalls, hasLength(3));
    expect([for (final call in engine.renderCalls) call.pageIndex], [0, 1, 2]);
    expect(engine.renderCalls.every((c) => c.scale == CompressLevel.balanced.scale), isTrue);
    expect(engine.renderCalls.every((c) => c.jpegQuality == CompressLevel.balanced.jpegQuality),
        isTrue);
  });

  test('keeps the same number of pages and the same page sizes', () async {
    final dest = out('same.pdf');
    final result = await service.compress(
      source: source,
      level: CompressLevel.high,
      destination: dest,
      sourcePath: sourcePath,
    );
    expect(result.pageCount, 3);
    expect(await dest.exists(), isTrue);
    expect(result.byteLength, greaterThan(0));
    expect(await engine.readPageSizes(await dest.readAsBytes()), source.pageSizes);
  });

  test('never replaces the original', () async {
    await expectLater(
      service.compress(
        source: source,
        level: CompressLevel.balanced,
        destination: File(sourcePath),
        sourcePath: sourcePath,
      ),
      throwsEngine(EngineErrorCode.wouldOverwriteSource),
    );
    expect(await File(sourcePath).readAsString(), 'ORIGINAL');
    expect(engine.renderCalls, isEmpty);
  });

  test('refuses to overwrite an existing name', () async {
    final dest = out('taken.pdf');
    await dest.create(recursive: true);
    await dest.writeAsString('KEEP');
    await expectLater(
      service.compress(
        source: source,
        level: CompressLevel.balanced,
        destination: dest,
        sourcePath: sourcePath,
      ),
      throwsEngine(EngineErrorCode.destinationExists),
    );
    expect(await dest.readAsString(), 'KEEP');
  });

  test('cancels cleanly and leaves nothing behind', () async {
    final token = CancellationToken();
    final cancelling = _CancelOnSecondRender(token);
    final cancelService = ProcessingService(engine: cancelling, workDirectory: work);
    final dest = out('cancelled.pdf');
    await expectLater(
      cancelService.compress(
        source: source,
        level: CompressLevel.balanced,
        destination: dest,
        sourcePath: sourcePath,
        cancellation: token,
      ),
      throwsEngine(EngineErrorCode.cancelled),
    );
    expect(await dest.exists(), isFalse);
    expect(await leftovers(), isEmpty);
  });

  test('does not publish a file when verification fails', () async {
    engine.distortSizes = true;
    final dest = out('distorted.pdf');
    await expectLater(
      service.compress(
        source: source,
        level: CompressLevel.balanced,
        destination: dest,
        sourcePath: sourcePath,
      ),
      throwsEngine(EngineErrorCode.verificationFailed),
    );
    expect(await dest.exists(), isFalse);
  });

  test('closes every document it created', () async {
    await service.compress(
      source: source,
      level: CompressLevel.balanced,
      destination: out('closed.pdf'),
      sourcePath: sourcePath,
    );
    expect(engine.created, isNotEmpty);
    expect(engine.created.every((doc) => doc.closed), isTrue);
  });

  test('refuses a protected document unless it is allowed', () async {
    final locked = FakeDoc('locked', [a4], wasPasswordProtected: true);
    await expectLater(
      service.compress(
        source: locked,
        level: CompressLevel.balanced,
        destination: out('locked.pdf'),
        sourcePath: sourcePath,
      ),
      throwsEngine(EngineErrorCode.protectionWouldBeRemoved),
    );
    final result = await service.compress(
      source: locked,
      level: CompressLevel.balanced,
      destination: out('locked.pdf'),
      sourcePath: sourcePath,
      allowRemovingPasswordProtection: true,
    );
    expect(result.pageCount, 1);
  });
}
