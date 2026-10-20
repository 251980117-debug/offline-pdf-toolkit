import 'package:flutter/material.dart';

import '../engine/cancellation.dart';
import '../engine/engine_exception.dart';
import '../engine/processing_service.dart';
import 'dialogs.dart';

typedef Job = Future<List<WriteResult>> Function(
    CancellationToken token, bool allowRemovingPasswordProtection);

/// Runs a job behind a progress dialog with Cancel, and asks before saving
/// a protected document without its password. Returns null on failure.
abstract final class JobRunner {
  static Future<List<WriteResult>?> run(BuildContext context,
      {required String label, required Job job}) async {
    var allowUnprotect = false;
    while (context.mounted) {
      final token = CancellationToken();
      final outcome = await showDialog<_Outcome>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ProgressDialog(
            label: label, token: token, start: () => job(token, allowUnprotect)),
      );
      if (outcome == null || !context.mounted) return null;
      final results = outcome.results;
      if (results != null) return results;
      final error = outcome.error;
      if (error is EngineException) {
        if (error.code == EngineErrorCode.protectionWouldBeRemoved && !allowUnprotect) {
          if (!await confirmRemoveProtection(context)) return null;
          allowUnprotect = true;
          continue;
        }
        if (error.code == EngineErrorCode.cancelled) {
          showMessage(context, 'Cancelled. Nothing was saved.');
          return null;
        }
      }
      showMessage(context, messageFor(error!));
      return null;
    }
    return null;
  }
}

class _Outcome {
  const _Outcome({this.results, this.error});

  final List<WriteResult>? results;
  final Object? error;
}

class _ProgressDialog extends StatefulWidget {
  const _ProgressDialog({required this.label, required this.token, required this.start});

  final String label;
  final CancellationToken token;
  final Future<List<WriteResult>> Function() start;

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    widget.start().then(
      (results) {
        if (mounted) Navigator.pop(context, _Outcome(results: results));
      },
      onError: (Object error) {
        if (mounted) Navigator.pop(context, _Outcome(error: error));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(_cancelling ? 'Cancelling...' : '${widget.label}...')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelling
                ? null
                : () {
                    widget.token.cancel();
                    setState(() => _cancelling = true);
                  },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
