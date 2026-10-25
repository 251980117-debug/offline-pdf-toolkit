import 'dart:convert';
import 'dart:typed_data';

import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

class FakeDoc implements OpenedPdf {
  FakeDoc(this.id, this.pageSizes, {this.wasPasswordProtected = false});

  @override
  final String id;
  @override
  String get displayName => id;
  @override
  final List<PageSize> pageSizes;
  @override
  final bool wasPasswordProtected;
  bool closed = false;

  @override
  Future<void> close() async {
    closed = true;
  }
}

/// Encodes a plan as text listing each output page size, so tests can
/// simulate correct output, lost pages, wrong sizes and failures.
class FakeEngine implements PdfEngine {
  final Map<String, FakeDoc> files = {};
  final List<FakeDoc> created = [];
  final List<String> createdNames = [];
  int dropLastPages = 0;
  bool distortSizes = false;
  Object? encodeError;
  int encodeCalls = 0;
  int _next = 0;

  @override
  Future<OpenedPdf> openFile(String path, {String? password}) async {
    final doc = files[path];
    if (doc == null) {
      throw const EngineException(EngineErrorCode.unreadable, 'missing');
    }
    return doc;
  }

  @override
  Future<OpenedPdf> createFromJpeg(Uint8List jpegBytes,
      {required PageSize pageSize, required String displayName}) async {
    final doc = FakeDoc('img-${_next++}', [pageSize]);
    created.add(doc);
    createdNames.add(displayName);
    return doc;
  }

  @override
  Future<Uint8List> encode(PagePlan plan, Map<String, OpenedPdf> sources) async {
    encodeCalls++;
    final error = encodeError;
    if (error != null) throw error;
    var sizes = [
      for (final ref in plan.pages)
        sources[ref.sourceId]!.pageSizes[ref.pageIndex].rotated(ref.turn),
    ];
    if (dropLastPages > 0) sizes = sizes.sublist(0, sizes.length - dropLastPages);
    if (distortSizes) sizes = [for (final s in sizes) PageSize(s.width + 10, s.height)];
    final text = ['FAKEPDF', for (final s in sizes) '${s.width},${s.height}'].join('\n');
    return Uint8List.fromList(utf8.encode(text));
  }

  @override
  Future<List<PageSize>> readPageSizes(Uint8List pdfBytes) async {
    final lines = utf8.decode(pdfBytes).split('\n');
    if (lines.first != 'FAKEPDF') throw const FormatException('Not a fake PDF.');
    return [
      for (final line in lines.skip(1))
        PageSize(double.parse(line.split(',')[0]), double.parse(line.split(',')[1])),
    ];
  }
}
