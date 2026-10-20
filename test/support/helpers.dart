import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

Matcher throwsPlan(PlanErrorCode code) =>
    throwsA(isA<PlanException>().having((e) => e.code, 'code', code));

Matcher throwsEngine(EngineErrorCode code) =>
    throwsA(isA<EngineException>().having((e) => e.code, 'code', code));

SourceDocument doc(String id, int pages) => SourceDocument(id: id, pageCount: pages);

List<PageRef> refs(String id, List<int> indexes) =>
    [for (final i in indexes) PageRef(id, i)];
