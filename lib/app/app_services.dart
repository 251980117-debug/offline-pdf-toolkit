import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../engine/pdfrx_engine.dart';
import '../engine/processing_service.dart';
import 'output_store.dart';

/// Created once at startup. Everything stays in app-private storage.
class AppServices {
  AppServices._(this.engine, this.processing, this.outputs, this.importsDirectory);

  static late final AppServices instance;

  final PdfrxEngine engine;
  final ProcessingService processing;
  final OutputStore outputs;

  /// Copies of picked files that had no readable path. Cleared each launch.
  final Directory importsDirectory;

  static Future<void> initialize() async {
    await PdfrxEngine.initialize();
    final temp = await getTemporaryDirectory();
    final documents = await getApplicationDocumentsDirectory();
    final engine = PdfrxEngine();
    final processing = ProcessingService(
        engine: engine, workDirectory: Directory(p.join(temp.path, 'work')));
    await processing.cleanUpUnfinished();
    final imports = Directory(p.join(temp.path, 'imports'));
    if (await imports.exists()) await imports.delete(recursive: true);
    await imports.create(recursive: true);
    final outputs = OutputStore(Directory(p.join(documents.path, 'Saved PDFs')));
    await outputs.directory.create(recursive: true);
    instance = AppServices._(engine, processing, outputs, imports);
  }
}
