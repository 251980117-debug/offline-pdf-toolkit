import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../core/output_namer.dart';
import '../engine/image_export_service.dart';
import 'dialogs.dart';
import 'format.dart';
import 'job_runner.dart';
import 'widgets/page_thumbnail.dart';

/// PDF to Images: saves every page as its own JPG file, in page order.
class PdfImagesScreen extends StatefulWidget {
  const PdfImagesScreen({super.key});

  @override
  State<PdfImagesScreen> createState() => _PdfImagesScreenState();
}

class _PdfImagesScreenState extends State<PdfImagesScreen> {
  PickedPdf? _picked;
  ImageExportPreset _preset = ImageExportPreset.balanced;
  bool _picking = false;
  List<File>? _exported;

  @override
  void dispose() {
    _picked?.document.close();
    super.dispose();
  }

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final picked = await DocumentOpener.pickPdfs(context, multiple: false);
      if (!mounted) {
        for (final item in picked) {
          await item.document.close();
        }
        return;
      }
      // Cancelling the picker leaves this screen as it was.
      if (picked.isEmpty) return;
      setState(() => _picked = picked.first);
    } on Object catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _export() async {
    final picked = _picked!;
    final preset = _preset;
    final destination = await _freshFolder(picked);
    if (!mounted) return;
    final service = ImageExportService(engine: AppServices.instance.engine);
    // JobRunner reports success as a non-null result list, but this job makes
    // images rather than one PDF, so the files are collected here instead.
    List<File>? exported;
    final results = await JobRunner.run(
      context,
      label: 'Exporting images',
      job: (token, _) async {
        exported = await service.exportPages(
          source: picked.document,
          destination: destination,
          preset: preset,
          cancellation: token,
        );
        return const [];
      },
    );
    if (results == null || exported == null || !mounted) return;
    setState(() => _exported = exported);
  }

  /// A new folder under app documents, so a second export never overwrites
  /// the pages of the first.
  Future<Directory> _freshFolder(PickedPdf picked) async {
    final documents = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(documents.path, 'images'));
    final base = OutputNamer.sanitizeBaseName(
        p.basenameWithoutExtension(picked.document.displayName));
    var folder = Directory(p.join(root.path, base));
    for (var n = 2; await folder.exists(); n++) {
      folder = Directory(p.join(root.path, '$base ($n)'));
    }
    return folder;
  }

  Future<void> _shareFrom(BuildContext shareContext, List<File> files) async {
    final box = shareContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [for (final file in files) XFile(file.path, mimeType: 'image/jpeg')],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _saveToDevice(File file) async {
    final uri = await FilePicker.saveFile(
        fileName: p.basename(file.path), bytes: await file.readAsBytes());
    if (uri != null && mounted) showMessage(context, 'Saved to your device.');
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final exported = _exported;
    return Scaffold(
      appBar: AppBar(title: const Text('PDF to Images')),
      body: picked == null
          ? _empty()
          : exported == null
              ? _body(picked)
              : _grid(picked, exported),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: exported == null
                ? FilledButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Export pages'),
                    onPressed: picked == null || _picking ? null : _export,
                  )
                : Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Save all'),
                      onPressed: () => _shareFrom(buttonContext, exported),
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Turn pages into images', style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Every page is saved as its own JPG file, named page-001, page-002 and so '
              'on, so the page order is kept.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Choose a PDF'),
              onPressed: _picking ? null : _pick,
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(PickedPdf picked) {
    final text = Theme.of(context).textTheme;
    final count = picked.document.pageSizes.length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(picked.document.displayName, style: text.titleMedium),
        Text('$count page${count == 1 ? '' : 's'} · ${formatBytes(File(picked.path).lengthSync())}',
            style: text.bodyMedium),
        const SizedBox(height: 20),
        SegmentedButton<ImageExportPreset>(
          segments: [
            for (final preset in ImageExportPreset.values)
              ButtonSegment(value: preset, label: Text(preset.label)),
          ],
          selected: {_preset},
          onSelectionChanged: (value) => setState(() => _preset = value.first),
        ),
        const SizedBox(height: 8),
        Text(_preset.description, style: text.bodySmall),
        const SizedBox(height: 4),
        Text('${_preset.dpi} dpi · JPEG quality ${_preset.jpegQuality}', style: text.bodySmall),
        const SizedBox(height: 20),
        Text(
          'Each page becomes one JPG file of about ${_preset.dpi} dpi, saved inside this app.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text('Your original file is not changed.', style: text.bodySmall),
      ],
    );
  }

  Widget _grid(PickedPdf picked, List<File> files) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(picked.document.displayName, style: text.titleMedium),
              Text('${files.length} image${files.length == 1 ? '' : 's'} exported',
                  style: text.bodyMedium),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) => _tile(picked, files[index], index),
          ),
        ),
      ],
    );
  }

  /// One page: its preview, the exported file's name and size, and its own
  /// save action. Tapping the tile shares that one image.
  Widget _tile(PickedPdf picked, File file, int pageIndex) {
    final text = Theme.of(context).textTheme;
    return Builder(
      builder: (tileContext) => InkWell(
        onTap: () => _shareFrom(tileContext, [file]),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: PageThumbnail(
                    document: picked.document, pageIndex: pageIndex, size: 96),
              ),
            ),
            const SizedBox(height: 6),
            Text(p.basename(file.path),
                style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatBytes(file.lengthSync()), style: text.bodySmall),
                IconButton(
                  tooltip: 'Save to device',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.download_outlined, size: 18),
                  onPressed: () => _saveToDevice(file),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
