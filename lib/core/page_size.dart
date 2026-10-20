import 'quarter_turn.dart';

/// Page dimensions in PDF points (1/72 inch).
class PageSize {
  const PageSize(this.width, this.height);

  final double width;
  final double height;

  PageSize rotated(QuarterTurn turn) =>
      turn.swapsDimensions ? PageSize(height, width) : this;

  /// True when both pages have the same dimensions in either orientation.
  /// Used to verify output without depending on how rotation is reported.
  bool matchesIgnoringRotation(PageSize other, {double tolerance = 0.5}) {
    bool close(double a, double b) => (a - b).abs() <= tolerance;
    return (close(width, other.width) && close(height, other.height)) ||
        (close(width, other.height) && close(height, other.width));
  }

  @override
  bool operator ==(Object other) =>
      other is PageSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'PageSize($width x $height pt)';
}
