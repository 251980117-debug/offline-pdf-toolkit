import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/helpers.dart';

void main() {
  List<int> parse(String input, [int count = 5]) =>
      PageRangeParser.parse(input, pageCount: count);

  test('parses pages and ranges in the order typed, zero-based', () {
    expect(parse('3, 1-2'), [2, 0, 1]);
    expect(parse('  2 - 4 '), [1, 2, 3]);
    expect(parse('5'), [4]);
  });

  test('keeps each part as a group for splitting', () {
    expect(PageRangeParser.parseGroups('1-2, 3, 4-5', pageCount: 5), [
      [0, 1],
      [2],
      [3, 4],
    ]);
  });

  test('rejects malformed input', () {
    expect(() => parse(''), throwsPlan(PlanErrorCode.emptySelection));
    expect(() => parse('   '), throwsPlan(PlanErrorCode.emptySelection));
    for (final bad in ['1,,2', '1,', 'a', '1-', '-2', '1-2-3', '2.5', '4-2']) {
      expect(() => parse(bad), throwsPlan(PlanErrorCode.invalidSyntax), reason: bad);
    }
  });

  test('rejects pages outside the document', () {
    for (final bad in ['0', '6', '4-6', '99999999999']) {
      expect(() => parse(bad), throwsPlan(PlanErrorCode.pageOutOfRange), reason: bad);
    }
  });

  test('formats pages back into readable ranges', () {
    expect(PageRangeParser.format([0, 1, 2, 4]), '1-3, 5');
    expect(PageRangeParser.format([2, 0, 1]), '3, 1-2');
    expect(PageRangeParser.format([]), '');
  });

  test('rejects pages selected twice', () {
    expect(() => parse('1-3, 2'), throwsPlan(PlanErrorCode.duplicatePage));
    expect(() => parse('4, 4'), throwsPlan(PlanErrorCode.duplicatePage));
  });
}
