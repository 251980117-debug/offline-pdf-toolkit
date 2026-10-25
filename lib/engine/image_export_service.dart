import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'cancellation.dart';
import 'engine_exception.dart';
import 'pdf_engine.dart';

/// Presets for image export: how many dots per inch each page is drawn at, and
/// how much JPEG detail to keep. Higher presets look sharper and are larger.
enum ImageExportPreset {
  compact(dpi: 110, jpegQuality: 65),
  balanced(dpi: 150, jpegQuality: 80),
  high(dpi: 200, jpegQuality: 90);

  const ImageExportPreset({required this.dpi, required this.jpegQuality});

  final int dpi;
  final int jpegQuality;

  /// PDF points are 72 per inch, so this is the render scale for [dpi].
  double get scale => dpi / 72;

  /// Short name for the selector.
  String get label => switch (this) {
        ImageExportPreset.compact => 'Compact',
        ImageExportPreset.balanced => 'Balanced',
        ImageExportPreset.high => 'High',
      };

  /// One line for the UI, explaining the size and clarity trade-off.
  String get description => switch (this) {
        ImageExportPreset.compact => 'Smallest files. Best for quick previews.',
        ImageExportPreset.balanced => 'A good balance of size and clarity.',
        ImageExportPreset.high => 'Most detail. Largest files.',
      };
}

/// Names one exported page. 1-based so the first file is page-001.jpg and
/// sorting by name keeps page order.
abstract final class ImageExportNaming {
  static const int digits = 3;

  static String nameFor(int pageIndex) =>
      'page-${(pageIndex + 1).toString().padLeft(digits, '0')}.jpg';
}

/// Exports every page of a document to its own JPG file, in page order.
class ImageExportService {
  ImageExportService({required this.engine});

  final PdfEngine engine;

  /// Renders pages 0..N-1 to `page-001.jpg` ... inside [destination], in order.
  /// Each file is written privately and only renamed into place once complete,
  /// so a cancelled or failed export leaves no images behind.
  /// Returns the finished files in page order. Never closes [source].
  Future<List<File>> exportPages({
    required OpenedPdf source,
    required Directory destination,
    required ImageExportPreset preset,
    CancellationToken? cancellation,
  }) async {
    final token = cancellation ?? CancellationToken();
    final created = <File>[];
    try {
      await destination.create(recursive: true);
      final files = <File>[];
      for (var i = 0; i < source.pageSizes.length; i++) {
        token.throwIfCancelled();
        final bytes = await _render(source, i, preset);
        final file = File(p.join(destination.path, ImageExportNaming.nameFor(i)));
        await _writePage(file, bytes);
        created.add(file);
        files.add(file);
      }
      // A cancel that arrives during the last render must not publish anything.
      token.throwIfCancelled();
      return files;
    } on EngineException {
      await _removeCreated(created);
      rethrow;
    } on FileSystemException catch (e) {
      await _removeCreated(created);
      throw EngineException(EngineErrorCode.storageFailure,
          'The images could not be exported. Check that the device has free space.',
          cause: e);
    } catch (e) {
      await _removeCreated(created);
      throw EngineException(EngineErrorCode.encodeFailed,
          'The images could not be exported. Your original file was not changed.',
          cause: e);
    }
  }

  Future<Uint8List> _render(
      OpenedPdf source, int pageIndex, ImageExportPreset preset) async {
    try {
      return await engine.renderPageAsJpeg(source, pageIndex,
          scale: preset.scale, jpegQuality: preset.jpegQuality);
    } on EngineException {
      rethrow;
    } catch (e) {
      throw EngineException(EngineErrorCode.encodeFailed,
          'Page ${pageIndex + 1} could not be exported as an image.', cause: e);
    }
  }

  /// Writes to a `.part` file first, so a half-written page is never visible.
  Future<void> _writePage(File file, Uint8List bytes) async {
    final partial = File('${file.path}.part');
    try {
      await partial.writeAsBytes(bytes, flush: true);
      if (await partial.length() != bytes.length) {
        throw const EngineException(EngineErrorCode.storageFailure,
            'A page image could not be saved completely.');
      }
      await partial.rename(file.path);
    } on EngineException {
      rethrow;
    } on FileSystemException catch (e) {
      throw EngineException(EngineErrorCode.storageFailure,
          'The images could not be exported. Check that the device has free space.',
          cause: e);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> _removeCreated(List<File> created) async {
    for (final file in created) {
      if (await file.exists()) await file.delete();
    }
  }
}
