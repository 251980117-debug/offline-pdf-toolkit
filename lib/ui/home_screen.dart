import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../app/app_services.dart';
import 'about_screen.dart';
import 'dialogs.dart';
import 'extract_split_screen.dart';
import 'format.dart';
import 'images_to_pdf_screen.dart';
import 'page_editor_screen.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<File>> _recent = AppServices.instance.outputs.recent();

  void _refresh() => setState(() => _recent = AppServices.instance.outputs.recent());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _refresh();
  }

  Future<void> _delete(File file) async {
    final ok = await confirmAction(context,
        title: 'Delete this PDF?',
        message: '"${p.basename(file.path)}" will be removed from this app.',
        confirmLabel: 'Delete');
    if (!ok) return;
    if (await file.exists()) await file.delete();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline PDF Toolkit'),
        actions: [
          IconButton(
            tooltip: 'Privacy and about',
            icon: const Icon(Icons.shield_outlined),
            onPressed: () => _open(const AboutScreen()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _PrivacyBanner(),
          const SizedBox(height: 20),
          Text('Tools', style: text.titleMedium),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _ToolCard(Icons.merge_type, 'Merge PDFs', 'PDFs and photos', () => _open(const PageEditorScreen(mode: EditorMode.merge))),
              _ToolCard(Icons.view_agenda_outlined, 'Organize pages', 'Reorder, rotate, delete',
                  () => _open(const PageEditorScreen(mode: EditorMode.organize))),
              _ToolCard(Icons.file_copy_outlined, 'Extract pages', 'Save selected pages',
                  () => _open(const ExtractSplitScreen(mode: PageToolMode.extract))),
              _ToolCard(Icons.call_split, 'Split PDF', 'Into several files',
                  () => _open(const ExtractSplitScreen(mode: PageToolMode.split))),
              _ToolCard(Icons.image_outlined, 'Images to PDF', 'Photos and scans',
                  () => _open(const ImagesToPdfScreen())),
            ],
          ),
          const SizedBox(height: 24),
          Text('Recent files', style: text.titleMedium),
          const SizedBox(height: 4),
          FutureBuilder<List<File>>(
            future: _recent,
            builder: (context, snapshot) {
              final files = snapshot.data ?? const <File>[];
              if (files.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('PDFs you create appear here.', style: text.bodyMedium),
                );
              }
              return Column(
                children: [
                  for (final file in files)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.picture_as_pdf_outlined),
                      title: Text(p.basename(file.path), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${formatBytes(file.lengthSync())} · '
                          '${formatDate(file.lastModifiedSync())}'),
                      onTap: () => _open(ResultScreen(files: [file], isNew: false)),
                      trailing: IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(file),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: scheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text('All document processing happens on this device. '
                  'Your files are never uploaded.',
                  style: TextStyle(color: scheme.onSecondaryContainer)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard(this.icon, this.title, this.subtitle, this.onTap);

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      color: scheme.surfaceContainerHighest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: scheme.primary, size: 28),
              const Spacer(),
              Text(title, style: text.titleSmall),
              Text(subtitle, style: text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
