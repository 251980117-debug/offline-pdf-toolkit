import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../core/page_operations.dart';
import '../core/page_plan.dart';
import '../core/quarter_turn.dart';
import '../engine/pdf_engine.dart';

/// Open documents, the current page plan and the page selection for the
/// page editor. Edits go through [PagePlan], so its rules always apply.
class WorkSession extends ChangeNotifier {
  final List<OpenedPdf> _documents = [];
  final Map<String, String> _paths = {};
  final Set<int> _selected = {};
  PagePlan _plan = PagePlan(const []);

  List<OpenedPdf> get documents => List.unmodifiable(_documents);
  PagePlan get plan => _plan;
  Set<int> get selected => Set.unmodifiable(_selected);
  Iterable<String> get sourcePaths => _paths.values;
  Map<String, OpenedPdf> get sourcesById => {for (final d in _documents) d.id: d};

  String get baseName => _documents.isEmpty
      ? 'document'
      : p.basenameWithoutExtension(_documents.first.displayName);

  OpenedPdf documentOf(PageRef ref) =>
      _documents.firstWhere((doc) => doc.id == ref.sourceId);

  void addDocument(OpenedPdf doc, String path) {
    _documents.add(doc);
    _paths[doc.id] = path;
    _plan = _plan.followedBy(PageOperations.wholeDocument(doc.toSource()));
    notifyListeners();
  }

  void toggle(int position) {
    if (!_selected.remove(position)) _selected.add(position);
    notifyListeners();
  }

  void selectAll() {
    _selected
      ..clear()
      ..addAll([for (var i = 0; i < _plan.length; i++) i]);
    notifyListeners();
  }

  void clearSelection() {
    _selected.clear();
    notifyListeners();
  }

  /// Moves a page. Selected pages stay selected.
  void move(int from, int to) {
    final next = _plan.move(from, to);
    final flags = [for (var i = 0; i < _plan.length; i++) _selected.contains(i)];
    flags.insert(to, flags.removeAt(from));
    _plan = next;
    _selected
      ..clear()
      ..addAll([for (var i = 0; i < flags.length; i++) if (flags[i]) i]);
    notifyListeners();
  }

  void rotateSelected(QuarterTurn turn) {
    _plan = _plan.rotatePositions(_selected, turn);
    notifyListeners();
  }

  void deleteSelected() {
    _plan = _plan.removePositions(_selected);
    _selected.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    for (final doc in _documents) {
      doc.close();
    }
    _documents.clear();
    super.dispose();
  }
}
