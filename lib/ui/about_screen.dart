import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget section(String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: 6),
              Text(body, style: text.bodyMedium),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy and about')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          section('Your files stay on this device',
              'Every PDF is opened and processed on your phone. The app has no account, '
                  'no server and no analytics. Files leave the app only when you share '
                  'or save them yourself.'),
          section('Your originals are safe',
              'Every tool creates a new copy. Original files are never changed. Each new '
                  'PDF is checked before it is saved, and nothing is saved if a step fails.'),
          section('Good to know',
              'Copies made from a password-protected PDF have no password. You are asked '
                  'before this happens. Digital signatures are not valid in a new copy. '
                  'Files stored in cloud services may need to download before they open.'),
          section('Version 1 tools',
              'Merge, organize, extract, split and images to PDF. Editing text, '
                  'recognizing text in scans and compressing existing PDFs are not included.'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(
                context: context, applicationName: 'Offline PDF Toolkit'),
          ),
        ],
      ),
    );
  }
}
