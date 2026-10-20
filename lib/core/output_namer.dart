import 'dart:math';

/// Builds safe, unique output file names. Never reuses an existing name.
abstract final class OutputNamer {
  static const int maxBaseLength = 100;
  static const int _maxAttempts = 9999;
  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
  static final RegExp _pdfExtension = RegExp(r'\.pdf$', caseSensitive: false);
  static final RegExp _whitespace = RegExp(r'\s+');
  static final RegExp _edgeDotsAndSpaces = RegExp(r'^[\s.]+|[\s.]+$');

  static String sanitizeBaseName(String raw) {
    var name = raw.trim().replaceFirst(_pdfExtension, '');
    name = name.replaceAll(_illegal, '_').replaceAll(_whitespace, ' ');
    name = name.replaceAll(_edgeDotsAndSpaces, '');
    if (name.isEmpty) return 'document';
    if (name.runes.length > maxBaseLength) {
      name = String.fromCharCodes(name.runes.take(maxBaseLength)).trimRight();
    }
    return name;
  }

  /// For example "Invoice - merged.pdf", then "Invoice - merged (2).pdf".
  /// [isTaken] should compare case-insensitively on case-insensitive storage.
  static String uniqueName({
    required String baseName,
    required String label,
    required bool Function(String fileName) isTaken,
  }) =>
      _firstFree('${sanitizeBaseName(baseName)} - ${sanitizeBaseName(label)}',
          isTaken);

  /// Names for split output: "Report - part 01.pdf", "Report - part 02.pdf".
  static List<String> uniqueSeries({
    required String baseName,
    required int count,
    required bool Function(String fileName) isTaken,
  }) {
    if (count < 1) throw ArgumentError.value(count, 'count', 'Must be at least 1.');
    final width = max(2, count.toString().length);
    final base = sanitizeBaseName(baseName);
    final chosen = <String>{};
    final names = <String>[];
    for (var i = 1; i <= count; i++) {
      final name = _firstFree(
        '$base - part ${i.toString().padLeft(width, '0')}',
        (candidate) => isTaken(candidate) || chosen.contains(candidate.toLowerCase()),
      );
      chosen.add(name.toLowerCase());
      names.add(name);
    }
    return names;
  }

  static String _firstFree(String stem, bool Function(String) isTaken) {
    final first = '$stem.pdf';
    if (!isTaken(first)) return first;
    for (var n = 2; n <= _maxAttempts; n++) {
      final candidate = '$stem ($n).pdf';
      if (!isTaken(candidate)) return candidate;
    }
    throw StateError('No free file name for "$stem".');
  }
}
