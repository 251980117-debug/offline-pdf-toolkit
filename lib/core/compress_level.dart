/// Presets for compress: how many dots per inch to re-draw each page at, and
/// how much JPEG detail to keep. Higher levels look sharper and are larger.
enum CompressLevel {
  compact(dpi: 110, jpegQuality: 60),
  balanced(dpi: 150, jpegQuality: 75),
  high(dpi: 200, jpegQuality: 85);

  const CompressLevel({required this.dpi, required this.jpegQuality});

  final int dpi;
  final int jpegQuality;

  /// PDF points are 72 per inch, so this is the render scale for [dpi].
  double get scale => dpi / 72;

  /// Short name for the selector.
  String get label => switch (this) {
        CompressLevel.compact => 'Compact',
        CompressLevel.balanced => 'Balanced',
        CompressLevel.high => 'High',
      };

  /// One line for the UI, explaining the size and clarity trade-off.
  String get description => switch (this) {
        CompressLevel.compact => 'Smallest file. Best for scans and photos.',
        CompressLevel.balanced => 'A good balance of size and clarity.',
        CompressLevel.high => 'Most detail. Largest file.',
      };
}
