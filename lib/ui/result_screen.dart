import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';

import 'dialogs.dart';
import 'format.dart';

/// Preview, share and export finished PDFs.
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key, required this.files, this.isNew = true});

  final List<File> files;
  final bool isNew;

  Future<void> _share(BuildContext context, List<File> toShare) async {
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [for (final f in toShare) XFile(f.path, mimeType: 'application/pdf')],
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _saveToDevice(BuildContext context, File file) async {
    final uri = await FilePicker.saveFile(
        fileName: p.basename(file.path), bytes: await file.readAsBytes());
    if (uri != null && context.mounted) showMessage(context, 'Saved to your device.');
  }

  @override
  Widget build(BuildContext context) {
    final single = files.length == 1 ? files.first : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(single == null ? '${files.length} files created' : p.basename(single.path)),
      ),
      body: Column(
        children: [
          if (isNew)
            Material(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(single == null
                    ? 'All files were created and checked.'
                    : 'Your PDF was created and checked.'),
              ),
            ),
          Expanded(
            child: single != null
                ? PdfViewer.file(single.path)
                : ListView(
                    children: [
                      for (final file in files)
                        ListTile(
                          leading: const Icon(Icons.picture_as_pdf_outlined),
                          title: Text(p.basename(file.path)),
                          subtitle: Text(formatBytes(file.lengthSync())),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => ResultScreen(files: [file], isNew: false))),
                          trailing: Builder(
                            builder: (context) => IconButton(
                              tooltip: 'Share',
                              icon: const Icon(Icons.ios_share),
                              onPressed: () => _share(context, [file]),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (single != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Save to device'),
                    onPressed: () => _saveToDevice(context, single),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Builder(
                  builder: (context) => FilledButton.icon(
                    icon: const Icon(Icons.ios_share),
                    label: Text(single == null ? 'Share all' : 'Share'),
                    onPressed: () => _share(context, files),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
