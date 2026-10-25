import 'plan_exception.dart';
import 'quarter_turn.dart';

/// An opened document, described only by what planning needs.
class SourceDocument {
  SourceDocument({required this.id, required this.pageCount}) {
    if (id.isEmpty) throw ArgumentError.value(id, 'id', 'Must not be empty.');
    if (pageCount < 1) {
      throw ArgumentError.value(pageCount, 'pageCount', 'Must be at least 1.');
    }
  }

  final String id;
  final int pageCount;
}

/// One output page: a page of a source document plus an extra rotation.
class PageRef {
  const PageRef(this.sourceId, this.pageIndex, [this.turn = QuarterTurn.none]);

  final String sourceId;

  /// Zero-based index in the source document.
  final int pageIndex;
  final QuarterTurn turn;

  PageRef rotatedBy(QuarterTurn extra) =>
      PageRef(sourceId, pageIndex, turn.plus(extra));

  @override
  bool operator ==(Object other) =>
      other is PageRef &&
      other.sourceId == sourceId &&
      other.pageIndex == pageIndex &&
      other.turn == turn;

  @override
  int get hashCode => Object.hash(sourceId, pageIndex, turn);

  @override
  String toString() => 'PageRef($sourceId #${pageIndex + 1}'
      '${turn == QuarterTurn.none ? '' : ' +${turn.degrees}deg'})';
}

/// The exact, ordered list of pages an output document will contain.
/// Immutable: every edit returns a new plan.
class PagePlan {
  PagePlan(Iterable<PageRef> pages) : pages = List.unmodifiable(pages);

  final List<PageRef> pages;

  int get length => pages.length;
  bool get isEmpty => pages.isEmpty;

  /// Throws [PlanException] unless every page exists in an open source.
  void validateAgainst(Map<String, SourceDocument> sources) {
    if (pages.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptyResult, 'The result must contain at least one page.');
    }
    for (final ref in pages) {
      final source = sources[ref.sourceId];
      if (source == null) {
        throw const PlanException(PlanErrorCode.unknownSource,
            'A page refers to a document that is no longer open.');
      }
      if (ref.pageIndex < 0 || ref.pageIndex >= source.pageCount) {
        throw PlanException(PlanErrorCode.pageOutOfRange,
            'Page ${ref.pageIndex + 1} does not exist in a ${source.pageCount}-page document.');
      }
    }
  }

  PagePlan move(int from, int to) {
    _checkPosition(from);
    _checkPosition(to);
    final list = [...pages];
    final item = list.removeAt(from);
    list.insert(to, item);
    return PagePlan(list);
  }

  PagePlan removePositions(Iterable<int> positions) {
    final selected = _checkPositions(positions);
    if (selected.length == pages.length) {
      throw const PlanException(PlanErrorCode.emptyResult,
          "You can't remove every page. At least one page must remain.");
    }
    return PagePlan([
      for (var i = 0; i < pages.length; i++)
        if (!selected.contains(i)) pages[i],
    ]);
  }

  PagePlan rotatePositions(Iterable<int> positions, QuarterTurn turn) {
    final selected = _checkPositions(positions);
    return PagePlan([
      for (var i = 0; i < pages.length; i++)
        selected.contains(i) ? pages[i].rotatedBy(turn) : pages[i],
    ]);
  }

  /// Copies each selected position, inserting the copy right after the original.
  /// The result keeps every page, and the returned pair tells the caller which
  /// positions are the new copies so the selection can move to them.
  DuplicatedPages duplicatePositions(Set<int> positions) {
    final selected = _checkPositions(positions);
    final list = <PageRef>[];
    final copies = <int>{};
    for (var i = 0; i < pages.length; i++) {
      list.add(pages[i]);
      if (selected.contains(i)) {
        list.add(pages[i]);
        copies.add(list.length - 1);
      }
    }
    return DuplicatedPages(PagePlan(list), copies);
  }

  PagePlan rotateAll(QuarterTurn turn) =>
      PagePlan(pages.map((page) => page.rotatedBy(turn)));

  PagePlan followedBy(PagePlan other) => PagePlan([...pages, ...other.pages]);

  void _checkPosition(int position) {
    if (position < 0 || position >= pages.length) {
      throw PlanException(PlanErrorCode.pageOutOfRange,
          'Position ${position + 1} is outside 1-${pages.length}.');
    }
  }

  Set<int> _checkPositions(Iterable<int> positions) {
    final selected = <int>{};
    for (final position in positions) {
      _checkPosition(position);
      if (!selected.add(position)) {
        throw PlanException(PlanErrorCode.duplicatePage,
            'Page ${position + 1} is selected more than once.');
      }
    }
    if (selected.isEmpty) {
      throw const PlanException(
          PlanErrorCode.emptySelection, 'Select at least one page.');
    }
    return selected;
  }
}

/// The plan after duplication, plus the positions of the inserted copies.
/// Immutable: [copies] is unmodifiable, like [PagePlan.pages].
class DuplicatedPages {
  DuplicatedPages(this.plan, Iterable<int> copies)
      : copies = Set.unmodifiable(copies);

  final PagePlan plan;

  /// Positions of the inserted copies in [plan].
  final Set<int> copies;
}
