import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../core/image_sizing.dart';
import '../core/page_plan.dart';
import '../core/page_size.dart';
import '../core/plan_exception.dart';
import 'cancellation.dart';
import 'engine_exception.dart';
import 'image_preparer.dart';
import 'pdf_engine.dart';

class WriteResult {
  const WriteResult(
      {required this.file, required this.pageCount, required this.byteLength});

  final File file;
  final int pageCount;
  final int byteLength;
}

/// Runs every write through the version 1 data-integrity rules:
/// validate, encode, reopen and verify, write privately, then publish.
/// A file only appears at [destination] after it has been verified.
class ProcessingService {
  ProcessingService({required this.engine, required this.workDirectory, Random? random})
      : _random = random ?? Random.secure();

  final PdfEngine engine;

  /// App-private folder for unfinished files.
  final Directory workDirectory;
  final Random _random;

  Future<OpenedPdf> open(String path, {String? password}) async {
    final doc = await engine.openFile(path, password: password);
    if (doc.pageSizes.isEmpty) {
      await doc.close();
      throw const EngineException(
          EngineErrorCode.emptyDocument, 'This PDF has no pages.');
    }
    return doc;
  }

  /// Opens a photo as a one-page document so it can be merged with PDFs.
  /// The caller owns the document and must close it.
  Future<OpenedPdf> openImage(String path,
      {ImageQuality quality = ImageQuality.balanced}) async {
    final prepared =
        await ImagePreparer.prepare(await File(path).readAsBytes(), quality);
    return engine.createFromJpeg(
      prepared.jpegBytes,
      pageSize: ImageSizing.pageFor(prepared.size),
      displayName: p.basename(path),
    );
  }

  Future<WriteResult> writePlan({
    required PagePlan plan,
    required Map<String, OpenedPdf> sources,
    required File destination,
    Iterable<String> sourcePaths = const [],
    bool allowRemovingPasswordProtection = false,
    CancellationToken? cancellation,
  }) async {
    final token = cancellation ?? CancellationToken();
    for (final entry in sources.entries) {
      if (entry.key != entry.value.id) {
        throw ArgumentError('Source key ${entry.key} does not match ${entry.value.id}.');
      }
    }
    plan.validateAgainst(
        {for (final source in sources.values) source.id: source.toSource()});
    _checkProtection(plan, sources, allowRemovingPasswordProtection);
    await _checkDestination(destination, sourcePaths);
    token.throwIfCancelled();

    final expected = [
      for (final ref in plan.pages) sources[ref.sourceId]!.pageSizes[ref.pageIndex],
    ];

    final Uint8List bytes;
    try {
      bytes = await engine.encode(plan, sources);
    } on EngineException {
      rethrow;
    } catch (e) {
      throw EngineException(
          EngineErrorCode.encodeFailed, 'The new PDF could not be created.',
          cause: e);
    }
    if (bytes.isEmpty) {
      throw const EngineException(
          EngineErrorCode.encodeFailed, 'The new PDF could not be created.');
    }
    token.throwIfCancelled();

    await _verify(bytes, expected);
    token.throwIfCancelled();

    return _commit(bytes, destination, expected.length, token);
  }

  /// One page per image, in the order given.
  Future<WriteResult> imagesToPdf({
    required List<PreparedImage> images,
    required File destination,
    CancellationToken? cancellation,
  }) async {
    if (images.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptySelection, 'Choose at least one image.');
    }
    final token = cancellation ?? CancellationToken();
    final opened = <OpenedPdf>[];
    try {
      for (final (index, image) in images.indexed) {
        token.throwIfCancelled();
        opened.add(await engine.createFromJpeg(image.jpegBytes,
            pageSize: ImageSizing.pageFor(image.size),
            displayName: 'image-${index + 1}'));
      }
      return await writePlan(
        plan: PagePlan(opened.map((doc) => PageRef(doc.id, 0))),
        sources: {for (final doc in opened) doc.id: doc},
        destination: destination,
        cancellation: token,
      );
    } finally {
      for (final doc in opened) {
        await doc.close();
      }
    }
  }

  void _checkProtection(
      PagePlan plan, Map<String, OpenedPdf> sources, bool allowed) {
    if (allowed) return;
    final usesProtected =
        plan.pages.any((ref) => sources[ref.sourceId]!.wasPasswordProtected);
    if (usesProtected) {
      throw const EngineException(EngineErrorCode.protectionWouldBeRemoved,
          'This document is password protected. The new copy will not have a '
          'password. Confirm to continue.');
    }
  }

  Future<void> _checkDestination(File destination, Iterable<String> sourcePaths) async {
    if (p.extension(destination.path).toLowerCase() != '.pdf') {
      throw ArgumentError.value(destination.path, 'destination', 'Must end in .pdf.');
    }
    final target = _normalize(destination.path);
    if (sourcePaths.any((source) => _normalize(source) == target)) {
      throw const EngineException(EngineErrorCode.wouldOverwriteSource,
          "The result can't replace an original document. Choose a new name.");
    }
    if (await destination.exists()) {
      throw const EngineException(EngineErrorCode.destinationExists,
          'A file with this name already exists. Choose a new name.');
    }
  }

  Future<void> _verify(Uint8List bytes, List<PageSize> expected) async {
    final List<PageSize> actual;
    try {
      actual = await engine.readPageSizes(bytes);
    } catch (e) {
      throw EngineException(EngineErrorCode.verificationFailed,
          'The new PDF could not be reopened, so it was not saved.',
          cause: e);
    }
    if (actual.length != expected.length) {
      throw EngineException(EngineErrorCode.verificationFailed,
          'The new PDF has ${actual.length} pages instead of ${expected.length}, '
          'so it was not saved.');
    }
    for (var i = 0; i < expected.length; i++) {
      if (!actual[i].matchesIgnoringRotation(expected[i])) {
        throw EngineException(EngineErrorCode.verificationFailed,
            'Page ${i + 1} of the new PDF has unexpected dimensions, so it was not saved.');
      }
    }
  }

  Future<WriteResult> _commit(Uint8List bytes, File destination, int pageCount,
      CancellationToken token) async {
    await workDirectory.create(recursive: true);
    final partial = File(p.join(workDirectory.path, '.partial-${_randomToken()}.pdf'));
    var committed = false;
    var copiedToDestination = false;
    try {
      await partial.writeAsBytes(bytes, flush: true);
      if (await partial.length() != bytes.length) {
        throw const EngineException(EngineErrorCode.storageFailure,
            'The file could not be saved completely.');
      }
      token.throwIfCancelled();
      if (await destination.exists()) {
        throw const EngineException(EngineErrorCode.destinationExists,
            'A file with this name already exists. Choose a new name.');
      }
      await destination.parent.create(recursive: true);
      try {
        await partial.rename(destination.path);
      } on FileSystemException {
        // Different storage volume: copy instead of moving.
        copiedToDestination = true;
        await partial.copy(destination.path);
      }
      committed = true;
      return WriteResult(
          file: destination, pageCount: pageCount, byteLength: bytes.length);
    } on EngineException {
      rethrow;
    } on FileSystemException catch (e) {
      throw EngineException(EngineErrorCode.storageFailure,
          'The file could not be saved. Check that the device has free space.',
          cause: e);
    } finally {
      if (await partial.exists()) await partial.delete();
      if (!committed && copiedToDestination && await destination.exists()) {
        await destination.delete();
      }
    }
  }

  /// Removes unfinished files left by an interrupted session.
  Future<int> cleanUpUnfinished() async {
    if (!await workDirectory.exists()) return 0;
    var removed = 0;
    await for (final entity in workDirectory.list()) {
      if (entity is File && p.basename(entity.path).startsWith('.partial-')) {
        await entity.delete();
        removed++;
      }
    }
    return removed;
  }

  static String _normalize(String path) => p.normalize(p.absolute(path)).toLowerCase();

  String _randomToken() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();
}
