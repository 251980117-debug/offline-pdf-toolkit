import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../app/work_session.dart';
import '../core/plan_exception.dart';
import '../core/quarter_turn.dart';
import 'dialogs.dart';
import 'job_runner.dart';
import 'result_screen.dart';
import 'save_flow.dart';
import 'widgets/page_thumbnail.dart';

enum EditorMode { merge, organize }

/// Merge and Organize: one list of pages to reorder, rotate and delete.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({super.key, required this.mode});

  final EditorMode mode;

  @override
  State<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends State<PageEditorScreen> {
  final WorkSession _session = WorkSession();
  bool _busy = false;

  bool get _isMerge => widget.mode == EditorMode.merge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _addFiles(initial: true));
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _addFiles({bool initial = false}) async {
    setState(() => _busy = true);
    final picked = await DocumentOpener.pickPdfs(context, multiple: _isMerge);
    if (!mounted) {
      for (final item in picked) {
        await item.document.close();
      }
      return;
    }
    for (final item in picked) {
      _session.addDocument(item.document, item.path);
    }
    setState(() => _busy = false);
    if (initial && _session.documents.isEmpty) Navigator.pop(context);
  }

  void _guard(VoidCallback action) {
    try {
      action();
    } on PlanException catch (e) {
      showMessage(context, e.message);
    }
  }

  Future<void> _save() async {
    final destination = await chooseDestination(context,
        baseName: _session.baseName, label: _isMerge ? 'merged' : 'edited');
    if (destination == null || !mounted) return;
    final plan = _session.plan;
    final sources = _session.sourcesById;
    final paths = _session.sourcePaths.toList();
    final results = await JobRunner.run(
      context,
      label: 'Creating your PDF',
      job: (token, allowUnprotect) async => [
        await AppServices.instance.processing.writePlan(
          plan: plan,
          sources: sources,
          destination: destination,
          sourcePaths: paths,
          allowRemovingPasswordProtection: allowUnprotect,
          cancellation: token,
        ),
      ],
    );
    if (results == null || !mounted) return;
    await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ResultScreen(files: [for (final r in results) r.file])));
  }

  Future<void> _confirmLeave() async {
    final leave = _session.documents.isEmpty ||
        await confirmAction(context,
            title: 'Discard changes?',
            message: 'Nothing has been saved. Your original files are not affected.',
            confirmLabel: 'Discard');
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isMerge ? 'Merge PDFs' : 'Organize pages'),
          actions: [
            if (_isMerge)
              IconButton(
                tooltip: 'Add PDFs',
                icon: const Icon(Icons.note_add_outlined),
                onPressed: _busy ? null : _addFiles,
              ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            if (_session.documents.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                _Toolbar(
                  selectedCount: _session.selected.length,
                  totalCount: _session.plan.length,
                  onSelectAll: _session.selectAll,
                  onClear: _session.clearSelection,
                  onRotateLeft: () => _guard(() => _session.rotateSelected(QuarterTurn.clockwise270)),
                  onRotateRight: () => _guard(() => _session.rotateSelected(QuarterTurn.clockwise90)),
                  onDelete: () => _guard(_session.deleteSelected),
                ),
                const Divider(height: 1),
                Expanded(child: _pageList()),
              ],
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListenableBuilder(
              listenable: _session,
              builder: (context, _) {
                final needsMore = _isMerge && _session.documents.length < 2;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (needsMore && _session.documents.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text('Add at least one more PDF to merge.'),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Save as new PDF'),
                        onPressed: needsMore || _busy || _session.documents.isEmpty ? null : _save,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageList() {
    final pages = _session.plan.pages;
    return ReorderableListView.builder(
      itemCount: pages.length,
      onReorderItem: (from, to) => _session.move(from, to),
      itemBuilder: (context, index) {
        final ref = pages[index];
        final doc = _session.documentOf(ref);
        final rotated = ref.turn == QuarterTurn.none ? '' : ' · rotated ${ref.turn.degrees}°';
        return ListTile(
          key: ValueKey('${ref.sourceId}:${ref.pageIndex}'),
          onTap: () => _session.toggle(index),
          leading: PageThumbnail(document: doc, pageIndex: ref.pageIndex, turn: ref.turn),
          title: Text('Page ${index + 1}'),
          subtitle: Text('${doc.displayName}, page ${ref.pageIndex + 1}$rotated',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Checkbox(
            value: _session.selected.contains(index),
            onChanged: (_) => _session.toggle(index),
          ),
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.selectedCount,
    required this.totalCount,
    required this.onSelectAll,
    required this.onClear,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onDelete,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCount > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          TextButton(
            onPressed: hasSelection ? onClear : onSelectAll,
            child: Text(hasSelection ? '$selectedCount selected' : 'Select all'),
          ),
          const Spacer(),
          IconButton(
              tooltip: 'Rotate left',
              icon: const Icon(Icons.rotate_left),
              onPressed: hasSelection ? onRotateLeft : null),
          IconButton(
              tooltip: 'Rotate right',
              icon: const Icon(Icons.rotate_right),
              onPressed: hasSelection ? onRotateRight : null),
          IconButton(
              tooltip: 'Delete pages',
              icon: const Icon(Icons.delete_outline),
              onPressed: hasSelection && selectedCount < totalCount ? onDelete : null),
        ],
      ),
    );
  }
}
