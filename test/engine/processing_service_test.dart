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

void main() {
  late Directory root;
  late Directory work;
  late FakeEngine engine;
  late ProcessingService service;
  late FakeDoc a;
  late FakeDoc b;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('opt_test_');
    work = Directory(p.join(root.path, 'work'));
    engine = FakeEngine();
    service = ProcessingService(engine: engine, workDirectory: work);
    a = FakeDoc('a', [a4, letter]);
    b = FakeDoc('b', [a5]);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File out(String name) => File(p.join(root.path, 'out', name));

  Future<List<String>> leftovers() async {
    if (!await work.exists()) return [];
    final names = <String>[];
    await for (final entity in work.list()) {
      names.add(p.basename(entity.path));
    }
    return names;
  }

  test('writes a verified merge and leaves no unfinished files', () async {
    final dest = out('merged.pdf');
    final result = await service.writePlan(
      plan: PageOperations.merge([a.toSource(), b.toSource()]),
      sources: {'a': a, 'b': b},
      destination: dest,
    );
    expect(result.pageCount, 3);
    expect(await engine.readPageSizes(await dest.readAsBytes()), [a4, letter, a5]);
    expect(await leftovers(), isEmpty);
  });

  test('accepts rotated pages', () async {
    final plan = PageOperations.wholeDocument(a.toSource()).rotateAll(QuarterTurn.clockwise90);
    final result = await service.writePlan(plan: plan, sources: {'a': a}, destination: out('r.pdf'));
    expect(result.pageCount, 2);
  });

  test('never overwrites an original document', () async {
    final original = File(p.join(root.path, 'Original.pdf'));
    await original.writeAsString('ORIGINAL');
    for (final dest in [original, File(p.join(root.path, 'ORIGINAL.PDF'))]) {
      await expectLater(
        service.writePlan(
          plan: PageOperations.wholeDocument(a.toSource()),
          sources: {'a': a},
          destination: dest,
          sourcePaths: [original.path],
        ),
        throwsEngine(EngineErrorCode.wouldOverwriteSource),
      );
    }
    expect(await original.readAsString(), 'ORIGINAL');
    expect(engine.encodeCalls, 0);
  });

  test('never replaces an existing file', () async {
    final dest = out('taken.pdf');
    await dest.create(recursive: true);
    await dest.writeAsString('KEEP');
    await expectLater(
      service.writePlan(
          plan: PageOperations.wholeDocument(a.toSource()), sources: {'a': a}, destination: dest),
      throwsEngine(EngineErrorCode.destinationExists),
    );
    expect(await dest.readAsString(), 'KEEP');
  });

  test('does not save output with a missing page', () async {
    engine.dropLastPages = 1;
    final dest = out('broken.pdf');
    await expectLater(
      service.writePlan(
          plan: PageOperations.merge([a.toSource(), b.toSource()]),
          sources: {'a': a, 'b': b},
          destination: dest),
      throwsEngine(EngineErrorCode.verificationFailed),
    );
    expect(await dest.exists(), isFalse);
    expect(await leftovers(), isEmpty);
  });

  test('does not save output with wrong page dimensions', () async {
    engine.distortSizes = true;
    final dest = out('distorted.pdf');
    await expectLater(
      service.writePlan(
          plan: PageOperations.wholeDocument(a.toSource()), sources: {'a': a}, destination: dest),
      throwsEngine(EngineErrorCode.verificationFailed),
    );
    expect(await dest.exists(), isFalse);
  });

  test('reports library failures without saving', () async {
    engine.encodeError = StateError('native failure');
    final dest = out('failed.pdf');
    await expectLater(
      service.writePlan(
          plan: PageOperations.wholeDocument(a.toSource()), sources: {'a': a}, destination: dest),
      throwsEngine(EngineErrorCode.encodeFailed),
    );
    expect(await dest.exists(), isFalse);
  });

  test('requires confirmation before removing password protection', () async {
    final locked = FakeDoc('p', [a4], wasPasswordProtected: true);
    final plan = PageOperations.wholeDocument(locked.toSource());
    await expectLater(
      service.writePlan(plan: plan, sources: {'p': locked}, destination: out('p.pdf')),
      throwsEngine(EngineErrorCode.protectionWouldBeRemoved),
    );
    final result = await service.writePlan(
        plan: plan,
        sources: {'p': locked},
        destination: out('p.pdf'),
        allowRemovingPasswordProtection: true);
    expect(result.pageCount, 1);
  });

  test('a cancelled job saves nothing', () async {
    final token = CancellationToken()..cancel();
    final dest = out('cancelled.pdf');
    await expectLater(
      service.writePlan(
          plan: PageOperations.wholeDocument(a.toSource()),
          sources: {'a': a},
          destination: dest,
          cancellation: token),
      throwsEngine(EngineErrorCode.cancelled),
    );
    expect(engine.encodeCalls, 0);
    expect(await dest.exists(), isFalse);
  });

  test('rejects plans that refer to closed documents', () async {
    await expectLater(
      service.writePlan(
          plan: PagePlan(refs('gone', [0])), sources: {'a': a}, destination: out('x.pdf')),
      throwsPlan(PlanErrorCode.unknownSource),
    );
  });

  test('rejects documents without pages', () async {
    final empty = FakeDoc('e', []);
    engine.files['/empty.pdf'] = empty;
    await expectLater(service.open('/empty.pdf'), throwsEngine(EngineErrorCode.emptyDocument));
    expect(empty.closed, isTrue);
  });

  test('converts images to one page each, in order, and closes temporary documents', () async {
    final images = [
      PreparedImage(jpegBytes: Uint8List(1), size: const PixelSize(4000, 3000)),
      PreparedImage(jpegBytes: Uint8List(1), size: const PixelSize(1000, 2000)),
    ];
    final dest = out('images.pdf');
    final result = await service.imagesToPdf(images: images, destination: dest);
    expect(result.pageCount, 2);
    final sizes = await engine.readPageSizes(await dest.readAsBytes());
    expect(sizes[0].matchesIgnoringRotation(ImageSizing.pageFor(images[0].size)), isTrue);
    expect(sizes[1].matchesIgnoringRotation(ImageSizing.pageFor(images[1].size)), isTrue);
    expect(engine.created.every((d) => d.closed), isTrue);
    await expectLater(service.imagesToPdf(images: [], destination: out('none.pdf')),
        throwsPlan(PlanErrorCode.emptySelection));
  });

  test('splits into separately named files', () async {
    final three = FakeDoc('t', [a4, letter, a5]);
    final parts = PageOperations.splitEvery(three.toSource(), 1);
    final names = OutputNamer.uniqueSeries(
        baseName: 'Report.pdf', count: parts.length, isTaken: (n) => out(n).existsSync());
    for (var i = 0; i < parts.length; i++) {
      await service.writePlan(plan: parts[i], sources: {'t': three}, destination: out(names[i]));
    }
    for (final name in names) {
      expect(await engine.readPageSizes(await out(name).readAsBytes()), hasLength(1));
    }
  });

  test('cleans up only unfinished files after an interruption', () async {
    await work.create(recursive: true);
    await File(p.join(work.path, '.partial-abc.pdf')).writeAsString('x');
    await File(p.join(work.path, 'keep.txt')).writeAsString('x');
    expect(await service.cleanUpUnfinished(), 1);
    expect(await leftovers(), ['keep.txt']);
  });
}
