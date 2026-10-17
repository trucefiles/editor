import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:proto/se_adapter.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';

// Odd but valid bytes that a reprint would normalize.
const source =
    '# Shop  \n'
    '* [ ] milk\n'
    '\t* [X] eggs\n'
    '*   [ ] bread **fresh**\n'
    '\n'
    'Some text with trailing spaces   ';

Future<SeChecklist> pump(WidgetTester tester, {TextInputSource? input}) async {
  final model = SeChecklist(source);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SuperEditor(
          editor: model.editor,
          inputSource: input ?? TextInputSource.ime,
          componentBuilders: [
            TaskComponentBuilder(model.editor),
            ...defaultComponentBuilders,
          ],
        ),
      ),
    ),
  );
  return model;
}

List<String> lines(String text) => text.split('\n');

void main() {
  testWidgets('typing changes only the touched line', (tester) async {
    final model = await pump(tester);
    await tester.placeCaretInParagraph('1', 4); // after "milk"
    await tester.typeImeText(' and honey');
    expect(lines(model.text)[1], '* [ ] milk and honey');
    final others = [0, 2, 3, 4, 5];
    for (final i in others) {
      expect(lines(model.text)[i], lines(source)[i], reason: 'line $i');
    }
  });

  testWidgets('Enter splits the item at the caret (item 20.2)', (tester) async {
    final model = await pump(tester);
    await tester.placeCaretInParagraph('3', 5); // "bread| **fresh**"
    await tester.pressEnter();
    await tester.typeImeText('x');
    final l = lines(model.text);
    expect(l[3], '*   [ ] bread');
    expect(l[4], '*   [ ] x **fresh**');
    expect(l[5], '');
    expect(l[0], '# Shop  ');
    expect(l[2], '\t* [X] eggs');
  });

  testWidgets('Backspace at item start joins into the line above', (
    tester,
  ) async {
    final model = await pump(tester);
    debugPrint([for (final n in model.document) '${n.id}:${n.runtimeType}'].join(' '));
    await tester.placeCaretInParagraph('3', 0);
    await tester.pressBackspace();
    debugPrint('after 1 backspace:\n${model.text}\n---');
    debugPrint([for (final n in model.document) '${n.id}:${n.runtimeType}'].join(' '));
    await tester.pressBackspace();
    debugPrint('after 2 backspaces:\n${model.text}\n---');
  });

  testWidgets('Backspace on an empty top item keeps caret at start of the next (20.1)', (
    tester,
  ) async {
    final model = SeChecklist('- [ ] \n- [ ] second');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuperEditor(
            editor: model.editor,
            inputSource: TextInputSource.ime,
            componentBuilders: [
              TaskComponentBuilder(model.editor),
              ...defaultComponentBuilders,
            ],
          ),
        ),
      ),
    );
    await tester.placeCaretInParagraph('0', 0);
    await tester.pressBackspace();
    debugPrint('empty top: ${model.text} sel=${model.composer.selection}');
    await tester.pressDelete();
    debugPrint('after delete: ${model.text} sel=${model.composer.selection}');
  });

  testWidgets('checkbox tap toggles only its mark', (tester) async {
    final model = await pump(tester);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(lines(model.text)[2], '\t* [ ] eggs');
    expect(model.writes, hasLength(1));
  });

  testWidgets('Tab indents with the file indent style', (tester) async {
    final model = await pump(tester);
    await tester.placeCaretInParagraph('3', 0);
    await tester.pressTab();
    debugPrint('after tab:\n${model.text}\n---');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pressTab();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    debugPrint('after shift tab:\n${model.text}\n---');
  });

  testWidgets('arrow down keeps the caret column (20.3b)', (tester) async {
    final model = await pump(tester, input: TextInputSource.keyboard);
    await tester.placeCaretInParagraph('1', 2);
    await tester.pressDownArrow();
    debugPrint('down: ${model.composer.selection}');
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad2);
    debugPrint('numpad2 (no numlock arrow?): ${model.composer.selection}');
  });
}
