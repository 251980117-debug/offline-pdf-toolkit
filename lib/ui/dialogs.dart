import 'package:flutter/material.dart';

import '../core/plan_exception.dart';
import '../engine/engine_exception.dart';

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String messageFor(Object error) => switch (error) {
      PlanException(:final message) => message,
      EngineException(:final message) => message,
      _ => 'Something went wrong. Your original files were not changed.',
    };

Future<String?> showPasswordDialog(BuildContext context,
    {required String fileName, String? error}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Password required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('"$fileName" is protected. The password is used only to open it '
              'and is never saved.'),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(labelText: 'Password', errorText: error),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Skip file')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Open')),
      ],
    ),
  );
}

Future<String?> showNameDialog(BuildContext context, {required String suggested}) {
  final controller = TextEditingController(text: suggested);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Save as new PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'File name', suffixText: '.pdf'),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 12),
          Text(
            'Your original files are not changed. If a PDF is digitally signed, '
            'the signature is not valid in the new copy.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save')),
      ],
    ),
  );
}

Future<bool> confirmAction(BuildContext context,
    {required String title, required String message, required String confirmLabel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> confirmRemoveProtection(BuildContext context) => confirmAction(
      context,
      title: 'Save without a password?',
      message: 'This document is password protected. The new copy will not have '
          'a password, so anyone with the file can open it.',
      confirmLabel: 'Save without password',
    );
