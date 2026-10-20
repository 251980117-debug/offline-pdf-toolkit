import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

void main() {
  test('adds turns and wraps after a full rotation', () {
    expect(QuarterTurn.clockwise90.plus(QuarterTurn.clockwise90), QuarterTurn.clockwise180);
    expect(QuarterTurn.clockwise270.plus(QuarterTurn.clockwise180), QuarterTurn.clockwise90);
    expect(QuarterTurn.clockwise90.plus(QuarterTurn.clockwise270), QuarterTurn.none);
  });

  test('converts degrees, including negative values', () {
    expect(QuarterTurn.fromDegrees(0), QuarterTurn.none);
    expect(QuarterTurn.fromDegrees(450), QuarterTurn.clockwise90);
    expect(QuarterTurn.fromDegrees(-90), QuarterTurn.clockwise270);
    expect(() => QuarterTurn.fromDegrees(45), throwsArgumentError);
  });

  test('odd turns swap page dimensions', () {
    const a4 = PageSize(595, 842);
    expect(a4.rotated(QuarterTurn.clockwise90), const PageSize(842, 595));
    expect(a4.rotated(QuarterTurn.clockwise180), a4);
    expect(a4.matchesIgnoringRotation(const PageSize(842, 595)), isTrue);
    expect(a4.matchesIgnoringRotation(const PageSize(612, 792)), isFalse);
  });
}
