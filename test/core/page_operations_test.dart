import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/helpers.dart';

void main() {
  group('merge', () {
    test('keeps every page of every document in order', () {
      final plan = PageOperations.merge([doc('a', 2), doc('b', 3)]);
      expect(plan.pages, [...refs('a', [0, 1]), ...refs('b', [0, 1, 2])]);
    });
    test('needs two documents with unique ids', () {
      expect(() => PageOperations.merge([doc('a', 2)]), throwsPlan(PlanErrorCode.noSources));
      expect(() => PageOperations.merge([doc('a', 2), doc('a', 2)]), throwsArgumentError);
    });
  });

  group('extract', () {
    test('keeps original document order', () {
      expect(PageOperations.extract(doc('a', 5), [4, 0, 2]).pages, refs('a', [0, 2, 4]));
    });
    test('rejects empty, missing and repeated pages', () {
      expect(() => PageOperations.extract(doc('a', 5), []), throwsPlan(PlanErrorCode.emptySelection));
      expect(() => PageOperations.extract(doc('a', 5), [5]), throwsPlan(PlanErrorCode.pageOutOfRange));
      expect(() => PageOperations.extract(doc('a', 5), [-1]), throwsPlan(PlanErrorCode.pageOutOfRange));
      expect(() => PageOperations.extract(doc('a', 5), [1, 1]), throwsPlan(PlanErrorCode.duplicatePage));
    });
  });

  group('delete', () {
    test('removes only the selected pages', () {
      expect(PageOperations.deletePages(doc('a', 4), [1, 3]).pages, refs('a', [0, 2]));
    });
    test('never produces an empty document', () {
      expect(() => PageOperations.deletePages(doc('a', 2), [0, 1]), throwsPlan(PlanErrorCode.emptyResult));
    });
  });

  group('reorder', () {
    test('applies a full permutation', () {
      expect(PageOperations.reorder(doc('a', 3), [2, 0, 1]).pages, refs('a', [2, 0, 1]));
    });
    test('rejects anything that loses or repeats a page', () {
      for (final bad in [[0, 0, 1], [0, 1], [0, 1, 3], [0, 1, 2, 2]]) {
        expect(() => PageOperations.reorder(doc('a', 3), bad), throwsPlan(PlanErrorCode.notAPermutation), reason: '$bad');
      }
    });
  });

  group('split', () {
    test('splits into fixed-size parts covering every page once', () {
      final parts = PageOperations.splitEvery(doc('a', 5), 2);
      expect(parts.map((p) => p.pages).toList(), [refs('a', [0, 1]), refs('a', [2, 3]), refs('a', [4])]);
    });
    test('rejects part sizes that split nothing', () {
      expect(() => PageOperations.splitEvery(doc('a', 3), 0), throwsPlan(PlanErrorCode.invalidChunkSize));
      expect(() => PageOperations.splitEvery(doc('a', 3), 3), throwsPlan(PlanErrorCode.invalidChunkSize));
      expect(() => PageOperations.splitEvery(doc('a', 1), 1), throwsPlan(PlanErrorCode.invalidChunkSize));
    });
    test('splits by groups without overlap', () {
      final parts = PageOperations.splitByGroups(doc('a', 4), [[0, 1], [3]]);
      expect(parts.map((p) => p.pages).toList(), [refs('a', [0, 1]), refs('a', [3])]);
      expect(() => PageOperations.splitByGroups(doc('a', 4), [[0, 1], [1]]), throwsPlan(PlanErrorCode.duplicatePage));
      expect(() => PageOperations.splitByGroups(doc('a', 4), [[0], []]), throwsPlan(PlanErrorCode.emptySelection));
      expect(() => PageOperations.splitByGroups(doc('a', 4), []), throwsPlan(PlanErrorCode.emptySelection));
    });
  });
}
