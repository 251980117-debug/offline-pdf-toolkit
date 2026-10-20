import 'dart:io';

import 'package:path/path.dart' as p;

/// The app's folder of finished PDFs.
class OutputStore {
  OutputStore(this.directory);

  final Directory directory;

  File fileFor(String name) => File(p.join(directory.path, name));

  /// Case-insensitive, because iOS and Android storage often is.
  bool Function(String fileName) takenChecker() {
    final names = <String>{};
    if (directory.existsSync()) {
      for (final entity in directory.listSync()) {
        if (entity is File) names.add(p.basename(entity.path).toLowerCase());
      }
    }
    return (name) => names.contains(name.toLowerCase());
  }

  Future<List<File>> recent() async {
    if (!await directory.exists()) return [];
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) files.add(entity);
    }
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }
}
