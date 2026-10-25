import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_services.dart';
import '../app/document_opener.dart';
import '../core/compress_level.dart';
import 'dialogs.dart';
import 'format.dart';
import 'job_runner.dart';
import 'result_screen.dart';
import 'save_flow.dart';

/// Compress: re-draw every page as a picture at a lower resolution, so the
/// file gets smaller. Text stops being selectable.
class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  PickedPdf? _picked;
  CompressLevel _level = CompressLevel.balanced;
  bool _picking = false;

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

  Future<void> _save() async {
    final picked = _picked!;
    final destination = await chooseDestination(context,
        baseName: p.basenameWithoutExtension(picked.document.displayName),
        label: 'compressed');
    if (destination == null || !mounted) return;
    final originalLength = File(picked.path).lengthSync();
    final level = _level;
    final results = await JobRunner.run(
      context,
      label: 'Compressing your PDF',
      job: (token, allowUnprotect) async => [
        await AppServices.instance.processing.compress(
          source: picked.document,
          level: level,
          destination: destination,
          sourcePath: picked.path,
          allowRemovingPasswordProtection: allowUnprotect,
          cancellation: token,
        ),
      ],
    );
    if (results == null || !mounted) return;
    final result = results.single;
    // A file that is already small may not shrink at all, so say so first.
    if (result.byteLength >= originalLength &&
        !await _askNoGain(context, original: originalLength, compressed: result.byteLength)) {
      return;
    }
    if (!mounted) return;
    await Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => ResultScreen(files: [result.file])));
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      appBar: AppBar(title: const Text('Compress PDF')),
      body: picked == null ? _empty() : _body(picked),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.compress),
              label: const Text('Compress'),
              onPressed: picked == null || _picking ? null : _save,
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
            Icon(Icons.compress, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Make a PDF smaller', style: text.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Every page is re-drawn as a picture at a lower resolution, so the file '
              'gets smaller. This works best for scans and photos.',
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
        SegmentedButton<CompressLevel>(
          segments: [
            for (final level in CompressLevel.values)
              ButtonSegment(value: level, label: Text(level.label)),
          ],
          selected: {_level},
          onSelectionChanged: (value) => setState(() => _level = value.first),
        ),
        const SizedBox(height: 8),
        Text(_level.description, style: text.bodySmall),
        const SizedBox(height: 4),
        Text('${_level.dpi} dpi · JPEG quality ${_level.jpegQuality}', style: text.bodySmall),
        const SizedBox(height: 20),
        Text(
          'Compressing re-draws every page as a picture. It is great for scans and photos.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'In a PDF that is mostly text, the text will no longer be selectable or searchable.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text('Your original file is not changed.', style: text.bodySmall),
      ],
    );
  }
}

/// True to keep the result, false to try a smaller level.
Future<bool> _askNoGain(BuildContext context,
    {required int original, required int compressed}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('No size gain'),
      content: Text('This file did not get smaller: the result is ${formatBytes(compressed)}, '
          'about the same as the original (${formatBytes(original)}). It may already be '
          'compressed, or mostly text, which compressing does not shrink.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Try a smaller level')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true), child: const Text('Keep it')),
      ],
    ),
  );
  return result ?? false;
}
