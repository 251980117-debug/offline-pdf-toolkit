import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/helpers.dart';

void main() {
  final plan = PagePlan(refs('a', [0, 1, 2]));

  test('moves a page without losing any', () {
    expect(plan.move(0, 2).pages, refs('a', [1, 2, 0]));
    expect(plan.move(2, 0).pages, refs('a', [2, 0, 1]));
    expect(() => plan.move(0, 3), throwsPlan(PlanErrorCode.pageOutOfRange));
  });

  test('rotates only selected pages and accumulates turns', () {
    final rotated = plan
        .rotatePositions([1], QuarterTurn.clockwise90)
        .rotatePositions([1], QuarterTurn.clockwise90);
    expect(rotated.pages[1].turn, QuarterTurn.clockwise180);
    expect(rotated.pages[0].turn, QuarterTurn.none);
    expect(rotated.pages[2].turn, QuarterTurn.none);
    expect(plan.pages[1].turn, QuarterTurn.none, reason: 'plans are immutable');
  });

  test('removes pages but never all of them', () {
    expect(plan.removePositions([0, 2]).pages, refs('a', [1]));
    expect(() => plan.removePositions([0, 1, 2]), throwsPlan(PlanErrorCode.emptyResult));
    expect(() => plan.removePositions([1, 1]), throwsPlan(PlanErrorCode.duplicatePage));
    expect(() => plan.removePositions([]), throwsPlan(PlanErrorCode.emptySelection));
  });

  test('validates against open documents', () {
    plan.validateAgainst({'a': doc('a', 3)});
    expect(() => plan.validateAgainst({'b': doc('b', 3)}), throwsPlan(PlanErrorCode.unknownSource));
    expect(() => plan.validateAgainst({'a': doc('a', 2)}), throwsPlan(PlanErrorCode.pageOutOfRange));
    expect(() => PagePlan([]).validateAgainst({'a': doc('a', 3)}), throwsPlan(PlanErrorCode.emptyResult));
  });

  test('duplicates selected pages right after their originals', () {
    final result = plan.duplicatePositions({0, 2});
    expect(result.plan.pages, refs('a', [0, 0, 1, 2, 2]));
    expect(result.copies, {1, 4});
  });

  test('keeps every original page exactly once more', () {
    final once = plan.duplicatePositions({1});
    expect(once.plan.pages, refs('a', [0, 1, 1, 2]));
    final counted = <PageRef, int>{};
    for (final ref in once.plan.pages) {
      counted[ref] = (counted[ref] ?? 0) + 1;
    }
    expect(counted[const PageRef('a', 1)], 2, reason: 'the selected page gains one copy');
    expect(counted[const PageRef('a', 0)], 1, reason: 'unselected pages are untouched');
    expect(counted[const PageRef('a', 2)], 1);
    expect(plan.duplicatePositions({0, 1, 2}).plan.pages, refs('a', [0, 0, 1, 1, 2, 2]));
  });

  test('reports the positions of the copies', () {
    final result = plan.duplicatePositions({0, 2});
    expect(result.copies, isNotEmpty);
    for (final copy in result.copies) {
      expect(result.plan.pages[copy], result.plan.pages[copy - 1],
          reason: 'each copy sits directly after its original');
    }
    final copies = result.copies.toList()..sort();
    expect(result.plan.pages[copies.first], plan.pages[0],
        reason: 'the first copy repeats the first original');
    expect(result.plan.pages[copies.last], plan.pages[2],
        reason: 'the last copy repeats the last original');
  });

  test('rejects an empty selection', () {
    expect(() => plan.duplicatePositions({}), throwsPlan(PlanErrorCode.emptySelection));
  });

  test('rejects positions outside the plan', () {
    expect(() => plan.duplicatePositions({plan.length}),
        throwsPlan(PlanErrorCode.pageOutOfRange));
    expect(() => plan.duplicatePositions({-1}), throwsPlan(PlanErrorCode.pageOutOfRange));
  });

  test('duplicates a whole document through PageOperations', () {
    final result = PageOperations.duplicate(doc('a', 3), {0, 2});
    expect(result.plan.pages, refs('a', [0, 0, 1, 2, 2]));
    expect(result.copies, {1, 4});
  });

  test('cannot be modified from outside', () {
    expect(() => plan.pages.add(const PageRef('a', 0)), throwsUnsupportedError);
    final duplicated = plan.duplicatePositions({0});
    expect(() => duplicated.plan.pages.add(const PageRef('a', 0)), throwsUnsupportedError);
    expect(() => duplicated.copies.add(plan.length), throwsUnsupportedError);
  });
}
