import 'plan_exception.dart';

/// Parses user page input such as "1-3, 5, 8-10" (1-based, inclusive).
abstract final class PageRangeParser {
  static final RegExp _single = RegExp(r'^\d+$');
  static final RegExp _range = RegExp(r'^(\d+)\s*-\s*(\d+)$');
  static const int _maxDigits = 7;

  /// Formats zero-based indexes as 1-based ranges, for example "1-3, 5".
  static String format(Iterable<int> zeroBasedIndexes) {
    final pages = [for (final i in zeroBasedIndexes) i + 1];
    final parts = <String>[];
    var start = 0;
    while (start < pages.length) {
      var end = start;
      while (end + 1 < pages.length && pages[end + 1] == pages[end] + 1) {
        end++;
      }
      parts.add(start == end ? '${pages[start]}' : '${pages[start]}-${pages[end]}');
      start = end + 1;
    }
    return parts.join(', ');
  }

  /// Zero-based indexes in the order typed. Rejects any repeated page.
  static List<int> parse(String input, {required int pageCount}) =>
      parseGroups(input, pageCount: pageCount).expand((g) => g).toList();

  /// One zero-based group per comma-separated part, for splitting by range.
  static List<List<int>> parseGroups(String input, {required int pageCount}) {
    if (pageCount < 1) {
      throw ArgumentError.value(pageCount, 'pageCount', 'Must be at least 1.');
    }
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptySelection, 'Enter at least one page.');
    }
    final seen = <int>{};
    final groups = <List<int>>[];
    for (final rawPart in trimmed.split(',')) {
      final part = rawPart.trim();
      if (part.isEmpty) {
        throw const PlanException(
            PlanErrorCode.invalidSyntax, 'Remove the extra comma.');
      }
      late final String startText;
      late final String endText;
      if (_single.hasMatch(part)) {
        startText = part;
        endText = part;
      } else {
        final match = _range.firstMatch(part);
        if (match == null) {
          throw PlanException(PlanErrorCode.invalidSyntax,
              '"$part" is not a page number or range like 2-5.');
        }
        startText = match.group(1)!;
        endText = match.group(2)!;
      }
      if (startText.length > _maxDigits || endText.length > _maxDigits) {
        throw PlanException(PlanErrorCode.pageOutOfRange,
            'Pages must be between 1 and $pageCount.');
      }
      final start = int.parse(startText);
      final end = int.parse(endText);
      if (start > end) {
        throw PlanException(PlanErrorCode.invalidSyntax,
            'Write "$part" from the lower page to the higher page.');
      }
      if (start < 1 || end > pageCount) {
        throw PlanException(PlanErrorCode.pageOutOfRange,
            'Pages must be between 1 and $pageCount.');
      }
      final group = <int>[];
      for (var page = start; page <= end; page++) {
        if (!seen.add(page)) {
          throw PlanException(PlanErrorCode.duplicatePage,
              'Page $page is selected more than once.');
        }
        group.add(page - 1);
      }
      groups.add(group);
    }
    return groups;
  }
}
