import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'checklist_view_harness.dart';

/// Indenting and outdenting checklist items: Tab, swipes and mouse drags.
void main() {
  testWidgets('without a Done section, checked items stay in place', (
    tester,
  ) async {
    final list = await showChecklist(
      tester,
      '- [ ] a\n- [x] done\n- [ ] b',
      separateDone: false,
    );
    await tester.tapAndPump(field('b'));

    expect(find.text('1 done'), findsNothing);
    // The checked item is shown above, so b goes under it.
    await tester.pressAndPump(LogicalKeyboardKey.tab);

    expect(list.text, '- [ ] a\n- [x] done\n  - [ ] b');
    await list.close();
  });

  testWidgets('tab indents under the open item shown above', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [x] done\n- [ ] b');
    await tester.tapAndPump(field('b'));

    await tester.pressAndPump(LogicalKeyboardKey.tab);

    expect(list.text, '- [ ] a\n  - [ ] b\n- [x] done');
    expect(find.text('1 done'), findsOneWidget);
    await list.close();
  });

  testWidgets('tab in the done section indents under the done item above', (
    tester,
  ) async {
    final list = await showChecklist(tester, '- [ ] a\n- [x] d1\n- [x] d2');
    await tester.tapAndPump(field('d2'));

    await tester.pressAndPump(LogicalKeyboardKey.tab);

    expect(list.text, '- [ ] a\n- [x] d1\n  - [x] d2');
    await list.close();
  });

  testWidgets('swiping right indents, left outdents', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');

    await tester.dragAndSettle(field('b'), const Offset(100, 0));
    expect(list.text, '- [ ] a\n  - [ ] b');

    await tester.dragAndSettle(field('b'), const Offset(-100, 0));
    expect(list.text, '- [ ] a\n- [ ] b');
    await list.close();
  });

  testWidgets('a mouse drag indents from the checkbox, not the text', (
    tester,
  ) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');

    await tester.dragAndSettle(
      field('b'),
      const Offset(100, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(list.text, '- [ ] a\n- [ ] b', reason: 'selects text');

    await tester.dragAndSettle(
      find.byType(Checkbox).at(1),
      const Offset(100, 0),
      kind: PointerDeviceKind.mouse,
    );
    expect(list.text, '- [ ] a\n  - [ ] b');
    await list.close();
  });

  testWidgets('a mouse drag by one level outdents', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n  - [ ] b');
    final a = tester.getCenter(find.byType(Checkbox).at(0));
    final b = tester.getCenter(find.byType(Checkbox).at(1));

    // Left by the width of one level, as shown on screen.
    await tester.dragFrom(
      b,
      Offset(a.dx - b.dx, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();

    expect(list.text, '- [ ] a\n- [ ] b');
    await list.close();
  });

  testWidgets('a long press that moves, to select text, does not indent', (
    tester,
  ) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');

    final gesture = await tester.startGesture(tester.getCenter(field('b')));
    // A finger holding still still jitters a little.
    await gesture.moveBy(
      const Offset(1, 1),
      timeStamp: const Duration(milliseconds: 100),
    );
    final held = kLongPressTimeout + const Duration(milliseconds: 100);
    await tester.pump(held);
    await gesture.moveBy(const Offset(100, 0), timeStamp: held);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(list.text, '- [ ] a\n- [ ] b');
    await list.close();
  });

  testWidgets('a long item wraps, and a swipe on its text indents it', (
    tester,
  ) async {
    final long = 'long ' * 100;
    final list = await showChecklist(tester, '- [ ] a\n- [ ] $long');

    await tester.dragAndSettle(field(long), const Offset(100, 0));

    expect(list.text, '- [ ] a\n  - [ ] $long');
    await list.close();
  });

  testWidgets('a short swipe does nothing', (tester) async {
    final list = await showChecklist(tester, '- [ ] a\n- [ ] b');

    await tester.dragAndSettle(field('b'), const Offset(20, 0));

    expect(list.text, '- [ ] a\n- [ ] b');
    await list.close();
  });
}
