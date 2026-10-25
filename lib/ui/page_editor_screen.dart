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

enum _AddAction { files, photos }

enum _PhotoSource { camera, gallery }

/// Merge and Organize: one list of pages to reorder, rotate and delete.
class PageEditorScreen extends StatefulWidget {
  const PageEditorScreen({super.key, required this.mode, this.initialFiles = const []});

  final EditorMode mode;

  /// Files to open straight away, so a PDF can go from the file list into the
  /// editor without another picker.
  final List<String> initialFiles;

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
    WidgetsBinding.instance.addPostFrameCallback((_) =>
        widget.initialFiles.isEmpty ? _addFiles(initial: true) : _openInitial());
  }

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  Future<void> _addFiles({bool initial = false}) async {
    setState(() => _busy = true);
    try {
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
      if (initial && !_isMerge && _session.documents.isEmpty) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the files passed in, for "Open a PDF" and "Edit pages".
  Future<void> _openInitial() async {
    setState(() => _busy = true);
    try {
      for (final path in widget.initialFiles) {
        final doc = await DocumentOpener.openPath(context, path);
        if (!mounted) {
          await doc?.close();
          return;
        }
        if (doc != null) _session.addDocument(doc, path);
      }
      if (mounted && _session.documents.isEmpty) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Adds one blank A4 page at the end, to be dragged where it is needed.
  Future<void> _addBlankPage() async {
    setState(() => _busy = true);
    try {
      final doc = await AppServices.instance.processing.blankPage();
      if (!mounted) {
        await doc.close();
        return;
      }
      _session.addDocument(doc);
    } on Object catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Photos become one-page documents, so they merge like any other file.
  Future<void> _addPhotos() async {
    final source = await _askPhotoSource();
    if (source == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final List<PickedImage> photos;
      if (source == _PhotoSource.camera) {
        final shot = await DocumentOpener.takePhoto();
        photos = [?shot];
      } else {
        photos = await DocumentOpener.pickImages();
      }
      for (final photo in photos) {
        if (!mounted) return;
        try {
          final doc = await AppServices.instance.processing.openImage(photo.path);
          _session.addDocument(doc, photo.path);
        } on Object catch (error) {
          if (mounted) showMessage(context, '${photo.name}: ${messageFor(error)}');
        }
      }
    } on Object catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_PhotoSource?> _askPhotoSource() {
    if (!DocumentOpener.cameraAvailable) return Future.value(_PhotoSource.gallery);
    return showModalBottomSheet<_PhotoSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(context, _PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, _PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
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
              PopupMenuButton<_AddAction>(
                tooltip: 'Add files or photos',
                enabled: !_busy,
                icon: const Icon(Icons.note_add_outlined),
                onSelected: (action) => switch (action) {
                  _AddAction.files => _addFiles(),
                  _AddAction.photos => _addPhotos(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _AddAction.files,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.picture_as_pdf_outlined),
                      title: Text('Add PDF files'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _AddAction.photos,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.photo_library_outlined),
                      title: Text('Add photos'),
                    ),
                  ),
                ],
              ),
            IconButton(
              tooltip: 'Add blank page',
              icon: const Icon(Icons.post_add),
              onPressed: _busy ? null : _addBlankPage,
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _session,
          builder: (context, _) {
            if (_session.documents.isEmpty) {
              if (_isMerge && !_busy) return _emptyMerge();
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
                  onDuplicate: () => _guard(_session.duplicateSelected),
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
                        child: Text('Add at least one more file or photo to merge.'),
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

  Widget _emptyMerge() {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.merge_type, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Combine files into one PDF', style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Choose two or more PDFs or photos. Their pages join in the order you set.',
                style: text.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Add PDF files'),
              onPressed: _busy ? null : _addFiles,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Add photos'),
              onPressed: _busy ? null : _addPhotos,
            ),
          ],
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
    required this.onDuplicate,
    required this.onDelete,
  });

  final int selectedCount;
  final int totalCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onDuplicate;
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
              tooltip: 'Duplicate pages',
              icon: const Icon(Icons.content_copy),
              onPressed: hasSelection ? onDuplicate : null),
          IconButton(
              tooltip: 'Delete pages',
              icon: const Icon(Icons.delete_outline),
              onPressed: hasSelection && selectedCount < totalCount ? onDelete : null),
        ],
      ),
    );
  }
}
