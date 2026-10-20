/// A clockwise rotation, in quarter turns, added to a page's existing rotation.
enum QuarterTurn {
  none(0),
  clockwise90(1),
  clockwise180(2),
  clockwise270(3);

  const QuarterTurn(this.turns);

  final int turns;

  int get degrees => turns * 90;

  /// Whether this turn swaps the visible width and height of a page.
  bool get swapsDimensions => turns.isOdd;

  QuarterTurn plus(QuarterTurn other) =>
      QuarterTurn.values[(turns + other.turns) % 4];

  static QuarterTurn fromDegrees(int degrees) {
    if (degrees % 90 != 0) {
      throw ArgumentError.value(degrees, 'degrees', 'Must be a multiple of 90.');
    }
    return QuarterTurn.values[(degrees ~/ 90) % 4];
  }
}
