import 'dart:io';

import 'package:flutter/material.dart';

import '../app/app_services.dart';
import '../core/output_namer.dart';
import 'dialogs.dart';

/// Asks for a file name and returns a new, unused file in the app folder.
Future<File?> chooseDestination(BuildContext context,
    {required String baseName, required String label}) async {
  final outputs = AppServices.instance.outputs;
  final suggested = OutputNamer.uniqueName(
      baseName: baseName, label: label, isTaken: outputs.takenChecker());
  final typed = await showNameDialog(context,
      suggested: suggested.substring(0, suggested.length - '.pdf'.length));
  if (typed == null) return null;
  final base = OutputNamer.sanitizeBaseName(typed);
  final isTaken = outputs.takenChecker();
  var name = '$base.pdf';
  for (var n = 2; isTaken(name); n++) {
    name = '$base ($n).pdf';
  }
  return outputs.fileFor(name);
}
