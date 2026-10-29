import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

import '../editor_robot.dart';

/// Android keyboards in Visual edit: the batches of changes Gboard and
/// Samsung's keyboard send for Enter, as recorded on devices. Gboard sends
/// its autocorrect before the new line, Samsung's after it.
void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  /// The keyboard's text: the library puts two characters before the
  /// caret's row.
  TextEditingValue keyboardText() => imeClientGetter().currentTextEditingValue!;

  /// Sends one batch, each change made on the text the ones before leave.
  Future<void> send(
    WidgetTester tester,
    List<TextEditingDelta Function(TextEditingValue value)> batch,
  ) {
    var value = keyboardText();
    final deltas = [
      for (final change in batch)
        () {
          final delta = change(value);
          value = delta.apply(value);
          return delta;
        }(),
    ];
    return tester.ime.sendDeltas(deltas, getter: imeClientGetter);
  }

  /// Autocorrects [word] before the caret to [to].
  TextEditingDelta Function(TextEditingValue) correct(String word, String to) =>
      (value) {
        final start = value.text.lastIndexOf(word, value.selection.start);
        return TextEditingDeltaReplacement(
          oldText: value.text,
          replacementText: to,
          replacedRange: TextRange(start: start, end: start + word.length),
          selection: value.selection.start >= start + word.length
              ? TextSelection.collapsed(
                  offset: value.selection.start + to.length - word.length,
                )
              : value.selection,
          composing: TextRange.empty,
        );
      };

  /// A new line at the caret.
  TextEditingDelta newLine(TextEditingValue value) => TextEditingDeltaInsertion(
    oldText: value.text,
    textInserted: '\n',
    insertionOffset: value.selection.start,
    selection: TextSelection.collapsed(offset: value.selection.start + 1),
    composing: TextRange.empty,
  );

  final gboard = [correct('Helo', 'Hello'), newLine];
  final samsung = [newLine, correct('Helo', 'Hello')];

  /// The text of each row.
  List<String> rows() => [
    for (final node in SuperEditorInspector.findDocument()!)
      if (node is TextNode) node.text.toPlainText(),
  ];

  for (final (keyboard, batch) in [('Gboard', gboard), ('Samsung', samsung)]) {
    group('$keyboard: Enter with an autocorrect', () {
      testWidgets('at the end of an item adds an item', (tester) async {
        final text = TestDocument('- [ ] Helo');
        await pumpDocument(tester, text);
        await tester.caretIn(checkboxNodeOf(), 4);

        await send(tester, batch);
        await tester.typeImeText('x');

        expect(rows(), ['Hello', 'x']);
        expect(text.text, '- [ ] Hello\n- [ ] x');
      }, variant: android);

      testWidgets('in the middle of an item splits it', (tester) async {
        final text = TestDocument('- [ ] Helo,world');
        await pumpDocument(tester, text);
        await tester.caretIn(checkboxNodeOf(), 4);

        await send(tester, batch);
        await tester.typeImeText('x');

        expect(rows(), ['Hello', 'x,world']);
        expect(text.text, '- [ ] Hello\n- [ ] x,world');
      }, variant: android);

      testWidgets('at the end of a heading adds a paragraph', (tester) async {
        final text = TestDocument('# Helo');
        await pumpDocument(tester, text);
        await tester.caretIn(paragraphNodeOf(), 4);

        await send(tester, batch);
        await tester.typeImeText('x');

        expect(rows(), ['Hello', 'x']);
        expect(text.text, '# Hello\n\nx');
      }, variant: android);
    });
  }

  group('Enter alone', () {
    testWidgets('in an empty item ends the list', (tester) async {
      final text = TestDocument('- [ ] a\n- [ ] ');
      await pumpDocument(tester, text);
      await tester.caretIn(checkboxNodeOf(index: 1), 0);

      await send(tester, [newLine]);
      await tester.typeImeText('x');

      expect(rows(), ['a', 'x']);
      expect(text.text, '- [ ] a\n\nx');
    }, variant: android);

    testWidgets('at the start of an item adds an empty item above', (
      tester,
    ) async {
      final text = TestDocument('- [ ] abc');
      await pumpDocument(tester, text);
      await tester.caretIn(checkboxNodeOf(), 0);

      await send(tester, [newLine]);
      await tester.typeImeText('x');

      expect(rows(), ['', 'xabc']);
      expect(text.text, '- [ ] \n- [ ] xabc');
    }, variant: android);
  });

  testWidgets('typing while a box tap waits sends the tap first, and the '
      'text lands in its item, in one change of the document', (tester) async {
    final text = TestDocument(
      '- [ ] a\n- [ ] b',
      checkedItems: CheckedItems.moveToEnd,
    );
    await pumpDocument(tester, text);
    await tester.caretIn(checkboxNodeOf(index: 1), 1);
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    var changes = 0;
    final listener = FunctionalEditListener((_) => changes++);
    final library = tester.widget<SuperEditor>(find.byType(SuperEditor)).editor
      ..addListener(listener);
    addTearDown(() => library.removeListener(listener));

    await tester.typeImeText('x');

    expect(changes, 1);
    expect(rows(), ['bx', 'a']);
    expect(text.text, '- [ ] bx\n- [x] a');
  }, variant: android);
}
