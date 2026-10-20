import 'dart:math';

import 'page_plan.dart';
import 'plan_exception.dart';

/// Builds page plans for each version 1 tool. Pure and side-effect free.
abstract final class PageOperations {
  static PagePlan wholeDocument(SourceDocument source) => PagePlan(
      [for (var i = 0; i < source.pageCount; i++) PageRef(source.id, i)]);

  /// All pages of every document, in the order given.
  static PagePlan merge(List<SourceDocument> sources) {
    if (sources.length < 2) {
      throw const PlanException(
          PlanErrorCode.noSources, 'Choose at least two documents to merge.');
    }
    final ids = <String>{};
    for (final source in sources) {
      if (!ids.add(source.id)) {
        throw ArgumentError('Opened documents need unique ids; "${source.id}" repeats.');
      }
    }
    return PagePlan(sources.expand((source) => wholeDocument(source).pages));
  }

  /// Selected pages, kept in their original document order.
  static PagePlan extract(SourceDocument source, Iterable<int> pageIndexes) {
    final selected = _checkIndexes(source, pageIndexes).toList()..sort();
    return PagePlan(selected.map((i) => PageRef(source.id, i)));
  }

  static PagePlan deletePages(SourceDocument source, Iterable<int> pageIndexes) {
    final selected = _checkIndexes(source, pageIndexes);
    if (selected.length == source.pageCount) {
      throw const PlanException(PlanErrorCode.emptyResult,
          "You can't delete every page. At least one page must remain.");
    }
    return PagePlan([
      for (var i = 0; i < source.pageCount; i++)
        if (!selected.contains(i)) PageRef(source.id, i),
    ]);
  }

  /// [newOrder] must list every zero-based page index exactly once.
  static PagePlan reorder(SourceDocument source, List<int> newOrder) {
    final valid = newOrder.length == source.pageCount &&
        newOrder.toSet().length == source.pageCount &&
        newOrder.every((i) => i >= 0 && i < source.pageCount);
    if (!valid) {
      throw const PlanException(PlanErrorCode.notAPermutation,
          'The new order must include every page exactly once.');
    }
    return PagePlan(newOrder.map((i) => PageRef(source.id, i)));
  }

  static List<PagePlan> splitEvery(SourceDocument source, int pagesPerFile) {
    if (pagesPerFile < 1) {
      throw const PlanException(PlanErrorCode.invalidChunkSize,
          'Each file must contain at least one page.');
    }
    if (pagesPerFile >= source.pageCount) {
      throw PlanException(PlanErrorCode.invalidChunkSize,
          'Choose fewer than ${source.pageCount} pages per file, otherwise nothing is split.');
    }
    return [
      for (var start = 0; start < source.pageCount; start += pagesPerFile)
        PagePlan([
          for (var i = start; i < min(start + pagesPerFile, source.pageCount); i++)
            PageRef(source.id, i),
        ]),
    ];
  }

  /// One output file per group. A page may appear in only one group.
  static List<PagePlan> splitByGroups(SourceDocument source, List<List<int>> groups) {
    if (groups.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptySelection, 'Add at least one page range.');
    }
    final seen = <int>{};
    final plans = <PagePlan>[];
    for (final group in groups) {
      if (group.isEmpty) {
        throw const PlanException(PlanErrorCode.emptySelection,
            'Each part must contain at least one page.');
      }
      for (final index in group) {
        _checkRange(source, index);
        if (!seen.add(index)) {
          throw PlanException(PlanErrorCode.duplicatePage,
              'Page ${index + 1} is in more than one part.');
        }
      }
      plans.add(PagePlan(group.map((i) => PageRef(source.id, i))));
    }
    return plans;
  }

  static Set<int> _checkIndexes(SourceDocument source, Iterable<int> indexes) {
    final selected = <int>{};
    for (final index in indexes) {
      _checkRange(source, index);
      if (!selected.add(index)) {
        throw PlanException(PlanErrorCode.duplicatePage,
            'Page ${index + 1} is selected more than once.');
      }
    }
    if (selected.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptySelection, 'Select at least one page.');
    }
    return selected;
  }

  static void _checkRange(SourceDocument source, int index) {
    if (index < 0 || index >= source.pageCount) {
      throw PlanException(PlanErrorCode.pageOutOfRange,
          'Page ${index + 1} is outside 1-${source.pageCount}.');
    }
  }
}
