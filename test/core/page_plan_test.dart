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

  test('cannot be modified from outside', () {
    expect(() => plan.pages.add(const PageRef('a', 0)), throwsUnsupportedError);
  });
}
