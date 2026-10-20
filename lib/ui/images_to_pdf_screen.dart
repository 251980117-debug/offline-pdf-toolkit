import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../core/image_sizing.dart';
import '../engine/image_preparer.dart';
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
  bool _loaded = false;

  static const _qualityHelp = {
    ImageQuality.compact: 'Smallest file. Good for email and uploads.',
    ImageQuality.balanced: 'Clear text at a moderate size. Best for most documents.',
    ImageQuality.high: 'Most detail. Larger file.',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _add(initial: true));
  }

  Future<void> _add({bool initial = false}) async {
    final picked = await DocumentOpener.pickImages();
    if (!mounted) return;
    setState(() {
      _images.addAll(picked);
      _loaded = true;
    });
    if (initial && _images.isEmpty) Navigator.pop(context);
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
          IconButton(
              tooltip: 'Add images', icon: const Icon(Icons.add_photo_alternate_outlined), onPressed: _add),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            icon: const Icon(Icons.save_outlined),
            label: Text(_images.length < 2 ? 'Create PDF' : 'Create PDF with ${_images.length} pages'),
            onPressed: _images.isEmpty ? null : _save,
          ),
        ),
      ),
    );
  }
}
