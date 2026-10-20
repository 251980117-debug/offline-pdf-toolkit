import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

void main() {
  test('sanitizes base names', () {
    expect(OutputNamer.sanitizeBaseName('Invoice.PDF'), 'Invoice');
    expect(OutputNamer.sanitizeBaseName('a/b:c*?'), 'a_b_c__');
    expect(OutputNamer.sanitizeBaseName('  my   report  '), 'my report');
    expect(OutputNamer.sanitizeBaseName('   '), 'document');
    expect(OutputNamer.sanitizeBaseName('...'), 'document');
    expect(OutputNamer.sanitizeBaseName('x' * 150).length, OutputNamer.maxBaseLength);
  });

  test('never reuses a taken name', () {
    final taken = {'report - merged.pdf', 'report - merged (2).pdf'};
    final name = OutputNamer.uniqueName(
        baseName: 'Report.pdf', label: 'merged', isTaken: (n) => taken.contains(n.toLowerCase()));
    expect(name, 'Report - merged (3).pdf');
  });

  test('numbers split parts and avoids collisions', () {
    expect(OutputNamer.uniqueSeries(baseName: 'Report', count: 3, isTaken: (_) => false),
        ['Report - part 01.pdf', 'Report - part 02.pdf', 'Report - part 03.pdf']);
    expect(
        OutputNamer.uniqueSeries(
            baseName: 'Report', count: 2, isTaken: (n) => n == 'Report - part 02.pdf'),
        ['Report - part 01.pdf', 'Report - part 02 (2).pdf']);
    expect(OutputNamer.uniqueSeries(baseName: 'R', count: 120, isTaken: (_) => false).first,
        'R - part 001.pdf');
  });
}
