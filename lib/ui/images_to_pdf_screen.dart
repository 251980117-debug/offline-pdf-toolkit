import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../core/image_sizing.dart';
import '../engine/image_preparer.dart';
import 'dialogs.dart';
import 'job_runner.dart';
import 'result_screen.dart';
import 'save_flow.dart';

class ImagesToPdfScreen extends StatefulWidget {
  const ImagesToPdfScreen({super.key});

  @override
  State<ImagesToPdfScreen> createState() => _ImagesToPdfScreenState();
}

class _ImagesToPdfScreenState extends State<ImagesToPdfScreen> {
  final List<PickedImage> _images = [];
  ImageQuality _quality = ImageQuality.balanced;
  bool _picking = false;

  static const _qualityHelp = {
    ImageQuality.compact: 'Smallest file. Good for email and uploads.',
    ImageQuality.balanced: 'Clear text at a moderate size. Best for most documents.',
    ImageQuality.high: 'Most detail. Larger file.',
  };

  Future<void> _addImages() async {
    setState(() => _picking = true);
    try {
      final picked = await DocumentOpener.pickImages();
      if (!mounted || picked.isEmpty) return;
      setState(() => _images.addAll(picked));
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// One photo at a time, so a whole stack of pages can be scanned in a row.
  Future<void> _takePhoto() async {
    setState(() => _picking = true);
    try {
      final photo = await DocumentOpener.takePhoto();
      if (!mounted || photo == null) return;
      setState(() => _images.add(photo));
    } catch (error) {
      if (mounted) showMessage(context, messageFor(error));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final destination = await chooseDestination(context,
        baseName: p.basenameWithoutExtension(_images.first.name), label: 'images');
    if (destination == null || !mounted) return;
    final images = List<PickedImage>.of(_images);
    final quality = _quality;
    final results = await JobRunner.run(
      context,
      label: 'Creating your PDF',
      job: (token, _) async {
        final prepared = <PreparedImage>[];
        for (final image in images) {
          token.throwIfCancelled();
          prepared.add(await ImagePreparer.prepare(await File(image.path).readAsBytes(), quality));
        }
        return [
          await AppServices.instance.processing
              .imagesToPdf(images: prepared, destination: destination, cancellation: token),
        ];
      },
    );
    if (results == null || !mounted) return;
    await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ResultScreen(files: [for (final r in results) r.file])));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Images to PDF'),
        actions: [
          if (DocumentOpener.cameraAvailable)
            IconButton(
              tooltip: 'Take photo',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: _picking ? null : _takePhoto,
            ),
          IconButton(
            tooltip: 'Choose images',
            icon: const Icon(Icons.add_photo_alternate_outlined),
            onPressed: _picking ? null : _addImages,
          ),
        ],
      ),
      body: _images.isEmpty ? _empty(text) : _list(text),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: Text(_images.length < 2
                ? 'Create PDF'
                : 'Create PDF with ${_images.length} pages'),
            onPressed: _images.isEmpty || _picking ? null : _save,
          ),
        ),
      ),
    );
  }

  Widget _empty(TextTheme text) {
    final scheme = Theme.of(context).colorScheme;
    final camera = DocumentOpener.cameraAvailable;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Turn photos into a PDF', style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              camera
                  ? 'Take one photo at a time, or choose pictures you already have. '
                      'Each picture becomes one page.'
                  : 'Choose the pictures you want. Each picture becomes one page.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (camera)
              FilledButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Take photo'),
                onPressed: _picking ? null : _takePhoto,
              ),
            if (camera) const SizedBox(height: 8),
            if (camera)
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Choose images'),
                onPressed: _picking ? null : _addImages,
              )
            else
              FilledButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Choose images'),
                onPressed: _picking ? null : _addImages,
              ),
          ],
        ),
      ),
    );
  }

  Widget _list(TextTheme text) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<ImageQuality>(
                segments: const [
                  ButtonSegment(value: ImageQuality.compact, label: Text('Compact')),
                  ButtonSegment(value: ImageQuality.balanced, label: Text('Balanced')),
                  ButtonSegment(value: ImageQuality.high, label: Text('High')),
                ],
                selected: {_quality},
                onSelectionChanged: (value) => setState(() => _quality = value.first),
              ),
              const SizedBox(height: 8),
              Text(_qualityHelp[_quality]!, style: text.bodySmall),
              const SizedBox(height: 4),
              Text('One page per image. Drag to change the order.', style: text.bodySmall),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: _images.length,
            onReorderItem: (from, to) => setState(() {
              final item = _images.removeAt(from);
              _images.insert(to, item);
            }),
            itemBuilder: (context, index) {
              final image = _images[index];
              return ListTile(
                key: ValueKey(image.path),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.file(File(image.path),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 112,
                      errorBuilder: (_, _, _) => const SizedBox(
                          width: 56, height: 56, child: Icon(Icons.broken_image_outlined))),
                ),
                title: Text('Page ${index + 1}'),
                subtitle: Text(image.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _images.removeAt(index)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
