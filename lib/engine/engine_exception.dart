/// Why reading or writing a document failed. Messages are safe to show.
enum EngineErrorCode {
  passwordRequired,
  wrongPassword,
  unreadable,
  emptyDocument,
  unsupportedImage,
  encodeFailed,
  verificationFailed,
  destinationExists,
  wouldOverwriteSource,
  protectionWouldBeRemoved,
  cancelled,
  storageFailure,
}

class EngineException implements Exception {
  const EngineException(this.code, this.message, {this.cause});

  final EngineErrorCode code;
  final String message;

  /// The underlying error, for logs on the device only.
  final Object? cause;

  @override
  String toString() => 'EngineException(${code.name}): $message';
}
