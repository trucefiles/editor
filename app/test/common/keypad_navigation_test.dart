import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/common/keypad_navigation.dart';

void main() {
  late TextEditingController text;

  /// A text field holding two lines, the caret in the second.
  Future<void> editTwoLines(WidgetTester tester) async {
    text = TextEditingController(text: 'ab\ncde')
      ..selection = const TextSelection.collapsed(offset: 4);
    addTearDown(text.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => KeypadNavigation(child: child!),
        home: Material(
          child: TextField(controller: text, maxLines: null, autofocus: true),
        ),
      ),
    );
    await tester.pump();
  }

  final linux = TargetPlatformVariant.only(TargetPlatform.linux);

  testWidgets('keypad Home and End move within the line', (tester) async {
    await editTwoLines(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);
    expect(text.selection, const TextSelection.collapsed(offset: 3));

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
    expect(
      text.selection,
      const TextSelection.collapsed(offset: 6, affinity: TextAffinity.upstream),
    );
  }, variant: linux);

  testWidgets('Shift with a keypad key selects', (tester) async {
    await editTwoLines(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad1);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);

    expect(text.selection, const TextSelection(baseOffset: 4, extentOffset: 5));
  }, variant: linux);

  testWidgets('keypad digits stay digits with NumLock on', (tester) async {
    await editTwoLines(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.numLock);
    addTearDown(() => tester.sendKeyEvent(LogicalKeyboardKey.numLock));

    await tester.sendKeyEvent(LogicalKeyboardKey.numpad7);

    expect(text.selection, const TextSelection.collapsed(offset: 4));
  }, variant: linux);
}
