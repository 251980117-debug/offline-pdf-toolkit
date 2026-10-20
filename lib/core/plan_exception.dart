/// Why a requested page operation is not allowed.
enum PlanErrorCode {
  noSources,
  emptySelection,
  invalidSyntax,
  pageOutOfRange,
  duplicatePage,
  emptyResult,
  notAPermutation,
  invalidChunkSize,
  unknownSource,
  invalidImage,
}

/// A user-correctable problem with a request. [message] is safe to show.
class PlanException implements Exception {
  const PlanException(this.code, this.message);

  final PlanErrorCode code;
  final String message;

  @override
  String toString() => 'PlanException(${code.name}): $message';
}
