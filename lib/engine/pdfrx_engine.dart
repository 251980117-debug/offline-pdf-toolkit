import 'dart:typed_data';

import 'package:pdfrx/pdfrx.dart';

import '../core/page_plan.dart';
import '../core/page_size.dart';
import '../core/quarter_turn.dart';
import 'engine_exception.dart';
import 'pdf_engine.dart';

/// [PdfEngine] backed by pdfrx (PDFium). Call [initialize] once at startup.
class PdfrxEngine implements PdfEngine {
  int _nextId = 0;

  static Future<void> initialize() => pdfrxFlutterInitialize();

  String _newId() => 'doc-${_nextId++}';

  /// The pdfrx document behind [doc], for page previews. Null for other engines.
  static PdfDocument? pdfrxDocumentOf(OpenedPdf doc) =>
      doc is _PdfrxOpened ? doc.document : null;

  @override
  Future<OpenedPdf> openFile(String path, {String? password}) async {
    // Offer the password once. A provider that keeps answering would retry
    // a wrong password forever.
    var offered = false;
    Future<String?> provider() async {
      if (offered || password == null) return null;
      offered = true;
      return password;
    }

    try {
      final doc = await PdfDocument.openFile(path, passwordProvider: provider);
      return _PdfrxOpened(_newId(), path.split(RegExp(r'[\\/]')).last, doc,
          wasPasswordProtected: offered);
    } on PdfPasswordException catch (e) {
      throw EngineException(
        password == null
            ? EngineErrorCode.passwordRequired
            : EngineErrorCode.wrongPassword,
        password == null
            ? 'This PDF is password protected. Enter its password to continue.'
            : 'That password is not correct.',
        cause: e,
      );
    } on Exception catch (e) {
      throw EngineException(EngineErrorCode.unreadable,
          'This file could not be opened. It may be damaged or not a PDF.',
          cause: e);
    }
  }

  @override
  Future<OpenedPdf> createFromJpeg(
    Uint8List jpegBytes, {
    required PageSize pageSize,
    required String displayName,
  }) async {
    try {
      final doc = await PdfDocument.createFromJpegData(
        jpegBytes,
        width: pageSize.width,
        height: pageSize.height,
        sourceName: '$displayName.pdf',
      );
      return _PdfrxOpened(_newId(), displayName, doc, wasPasswordProtected: false);
    } on Exception catch (e) {
      throw EngineException(
          EngineErrorCode.unsupportedImage, 'This image could not be added.',
          cause: e);
    }
  }

  @override
  Future<Uint8List> encode(PagePlan plan, Map<String, OpenedPdf> sources) async {
    final output = await PdfDocument.createNew(sourceName: 'output.pdf');
    try {
      output.pages = [
        for (final ref in plan.pages) _pageFor(ref, sources),
      ];
      return await output.encodePdf();
    } finally {
      await Future.sync(output.dispose);
    }
  }

  @override
  Future<List<PageSize>> readPageSizes(Uint8List pdfBytes) async {
    final doc = await PdfDocument.openData(pdfBytes);
    try {
      return [for (final page in doc.pages) PageSize(page.width, page.height)];
    } finally {
      await Future.sync(doc.dispose);
    }
  }

  PdfPage _pageFor(PageRef ref, Map<String, OpenedPdf> sources) {
    final source = sources[ref.sourceId];
    if (source is! _PdfrxOpened) {
      throw ArgumentError('Source ${ref.sourceId} was not opened by this engine.');
    }
    final page = source.document.pages[ref.pageIndex];
    return switch (ref.turn) {
      QuarterTurn.none => page,
      QuarterTurn.clockwise90 => page.rotatedCW90(),
      QuarterTurn.clockwise180 => page.rotated180(),
      QuarterTurn.clockwise270 => page.rotatedCCW90(),
    };
  }
}

class _PdfrxOpened implements OpenedPdf {
  _PdfrxOpened(this.id, this.displayName, this.document,
      {required this.wasPasswordProtected})
      : pageSizes = List.unmodifiable(
            [for (final page in document.pages) PageSize(page.width, page.height)]);

  @override
  final String id;
  @override
  final String displayName;
  final PdfDocument document;
  @override
  final List<PageSize> pageSizes;
  @override
  final bool wasPasswordProtected;

  @override
  Future<void> close() => Future.sync(document.dispose);
}
