import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pdf_toolkit/app/work_session.dart';
import 'package:offline_pdf_toolkit/offline_pdf_toolkit.dart';

import '../support/fake_engine.dart';
import '../support/helpers.dart';

void main() {
  late WorkSession session;
  late FakeDoc a;
  late FakeDoc b;

  setUp(() {
    session = WorkSession();
    a = FakeDoc('a', const [PageSize(595, 842), PageSize(595, 842)]);
    b = FakeDoc('b', const [PageSize(612, 792)]);
    session.addDocument(a, '/files/a.pdf');
    session.addDocument(b, '/files/b.pdf');
  });

  test('adding documents appends all their pages', () {
    expect(session.plan.pages, [...refs('a', [0, 1]), ...refs('b', [0])]);
    expect(session.sourcePaths, ['/files/a.pdf', '/files/b.pdf']);
    expect(session.baseName, 'a');
  });

  test('rotates only selected pages', () {
    session.toggle(1);
    session.rotateSelected(QuarterTurn.clockwise90);
    expect(session.plan.pages[1].turn, QuarterTurn.clockwise90);
    expect(session.plan.pages[0].turn, QuarterTurn.none);
    expect(session.selected, {1});
  });

  test('selection follows a moved page', () {
    session.toggle(0);
    session.move(0, 2);
    expect(session.plan.pages.last, const PageRef('a', 0));
    expect(session.selected, {2});
  });

  test('deletes selected pages but never all of them', () {
    session.toggle(0);
    session.deleteSelected();
    expect(session.plan.length, 2);
    expect(session.selected, isEmpty);
    session.selectAll();
    expect(session.deleteSelected, throwsPlan(PlanErrorCode.emptyResult));
    expect(session.plan.length, 2);
  });

  test('closes documents when disposed', () {
    session.dispose();
    expect(a.closed && b.closed, isTrue);
  });
}
