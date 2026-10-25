import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../core/output_namer.dart';
import '../engine/engine_exception.dart';
import '../engine/pdf_engine.dart';
import '../ui/dialogs.dart';
import 'app_services.dart';

class PickedPdf {
  const PickedPdf(this.document, this.path);

  final OpenedPdf document;
  final String path;
}

class PickedImage {
  const PickedImage(this.name, this.path);

  final String name;
  final String path;
}

/// Picks files with the system picker and opens them on the device.
abstract final class DocumentOpener {
  static Future<List<PickedPdf>> pickPdfs(BuildContext context, {bool multiple = true}) async {
    final List<PlatformFile> files;
    if (multiple) {
      files = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    } else {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
      files = file == null ? [] : [file];
    }
    final picked = <PickedPdf>[];
    for (final file in files) {
      if (!context.mounted) break;
      final path = await localPath(file, extension: '.pdf');
      if (!context.mounted) break;
      final doc = await _openWithPassword(context, path, file.name);
      if (doc != null) picked.add(PickedPdf(doc, path));
    }
    return picked;
  }

  /// Opens a file that is already on the device, asking for a password when
  /// one is needed. Returns null when it cannot be opened.
  static Future<OpenedPdf?> openPath(BuildContext context, String path,
          {String? name}) =>
      _openWithPassword(context, path, name ?? p.basename(path));

  static Future<List<PickedImage>> pickImages() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    return [
      for (final file in files)
        PickedImage(file.name, await localPath(file, extension: p.extension(file.name))),
    ];
  }

  /// True where the system camera can be opened. Desktop builds have none.
  static bool get cameraAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Takes one photo with the camera and keeps a copy in app storage.
  /// Returns null when the user closes the camera without a picture.
  static Future<PickedImage?> takePhoto() async {
    final shot = await ImagePicker().pickImage(source: ImageSource.camera);
    if (shot == null) return null;
    return _keepPhoto(shot.path);
  }

  /// Camera photos can live in a folder the system clears, so copy them.
  static Future<PickedImage> _keepPhoto(String path) async {
    final name = p.basename(path);
    final extension = p.extension(name).isEmpty ? '.jpg' : p.extension(name);
    final target = File(p.join(
        AppServices.instance.importsDirectory.path,
        '${DateTime.now().microsecondsSinceEpoch}-'
        '${OutputNamer.sanitizeBaseName(p.basenameWithoutExtension(name))}$extension'));
    await target.writeAsBytes(await File(path).readAsBytes(), flush: true);
    return PickedImage(name, target.path);
  }

  /// A readable local path. Files without one are copied into app storage.
  static Future<String> localPath(PlatformFile file, {required String extension}) async {
    final existing = file.path;
    if (existing != null && await File(existing).exists()) return existing;
    final bytes = await file.readAsBytes();
    final name = '${DateTime.now().microsecondsSinceEpoch}-'
        '${OutputNamer.sanitizeBaseName(p.basenameWithoutExtension(file.name))}$extension';
    final target = File(p.join(AppServices.instance.importsDirectory.path, name));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  static Future<OpenedPdf?> _openWithPassword(
      BuildContext context, String path, String name) async {
    String? password;
    while (true) {
      try {
        return await AppServices.instance.processing.open(path, password: password);
      } on EngineException catch (e) {
        if (!context.mounted) return null;
        final needsPassword = e.code == EngineErrorCode.passwordRequired ||
            e.code == EngineErrorCode.wrongPassword;
        if (!needsPassword) {
          showMessage(context, '$name: ${e.message}');
          return null;
        }
        password = await showPasswordDialog(context,
            fileName: name,
            error: e.code == EngineErrorCode.wrongPassword ? e.message : null);
        if (password == null) return null;
      }
    }
  }
}
