import 'engine_exception.dart';

/// Checked between processing steps. A cancelled job never saves output.
class CancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) {
      throw const EngineException(
          EngineErrorCode.cancelled, 'The operation was cancelled.');
    }
  }
}
