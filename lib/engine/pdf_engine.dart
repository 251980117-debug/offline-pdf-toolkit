import 'dart:typed_data';

import '../core/page_plan.dart';
import '../core/page_size.dart';

/// A document opened by an engine. Close it when finished.
abstract interface class OpenedPdf {
  /// Unique while open. Used by [PageRef.sourceId].
  String get id;
  String get displayName;

  /// Size of each page as stored in the source, before any new rotation.
  List<PageSize> get pageSizes;

  /// True when a password was needed to open it.
  bool get wasPasswordProtected;

  Future<void> close();
}

extension OpenedPdfPlanning on OpenedPdf {
  int get pageCount => pageSizes.length;
  SourceDocument toSource() => SourceDocument(id: id, pageCount: pageCount);
}

/// The only boundary to the PDF library, so it can be replaced or faked.
abstract interface class PdfEngine {
  Future<OpenedPdf> openFile(String path, {String? password});

  Future<OpenedPdf> createFromJpeg(
    Uint8List jpegBytes, {
    required PageSize pageSize,
    required String displayName,
  });

  /// Builds a new PDF from [plan]. Must never modify any source.
  Future<Uint8List> encode(PagePlan plan, Map<String, OpenedPdf> sources);

  /// Reopens finished bytes and reports their page sizes, for verification.
  Future<List<PageSize>> readPageSizes(Uint8List pdfBytes);

  /// Renders one page to JPEG bytes at [scale] (1.0 = 72 dpi). Used to
  /// re-encode pages for compression and image export. Must not modify the source.
  Future<Uint8List> renderPageAsJpeg(OpenedPdf document, int pageIndex,
      {required double scale, int jpegQuality = 85});
}
