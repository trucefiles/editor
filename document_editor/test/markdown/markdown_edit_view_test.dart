import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// Editing a document in Markdown edit.
void main() {
  TestDocument markdown(String text) =>
      TestDocument(text, mode: EditMode.markdown);

  testWidgets('edits every character', (tester) async {
    final document = markdown('- [ ] milk');
    await pumpDocument(tester, document);
    expect(find.byType(Checkbox), findsNothing);

    await tester.caretIn(lineNodeOf(0), 4);
    await tester.typeImeText('x');

    expect(document.text, '- [ x] milk');
  });

  testWidgets('Enter makes a line', (tester) async {
    final document = markdown('a\r\nbc');
    await pumpDocument(tester, document);

    await tester.caretIn(lineNodeOf(1), 1);
    await tester.pressEnter();
    await tester.typeImeText('x');

    expect(document.text, 'a\r\nb\r\nxc');
  });

  testWidgets('deleting every line at once leaves an empty document', (
    tester,
  ) async {
    final document = markdown('# Plan\n\nmine\n');
    await pumpDocument(tester, document);

    await tester.caretIn(lineNodeOf(0), 1);
    await tester.pressCtlA();
    await tester.pressBackspace();
    await tester.typeImeText('x');

    expect(tester.takeException(), isNull);
    expect(document.text, 'x');
  });

  testWidgets('Tab types a tab', (tester) async {
    final document = markdown('- a');
    await pumpDocument(tester, document);

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.pressTab();

    expect(document.text, '\t- a');
  });

  testWidgets('a heading shows larger, its marks dimmed', (tester) async {
    await pumpDocument(tester, markdown('# Title\n\ntext'));

    InlineSpan spanOf(String text) =>
        tester.widget<RichText>(find.text(text, findRichText: true).first).text;
    final (title, body) = (spanOf('# Title'), spanOf('text'));
    expect(
      _styleAt(title, 3).fontSize,
      greaterThan(_styleAt(body, 0).fontSize!),
    );
    expect(_styleAt(title, 0).color, isNot(_styleAt(title, 3).color));
  });

  testWidgets('a fence typed above restyles the lines below it', (
    tester,
  ) async {
    await pumpDocument(tester, markdown('x\n# Title'));
    InlineSpan spanOf(String text) =>
        tester.widget<RichText>(find.text(text, findRichText: true).first).text;
    final heading = _styleAt(spanOf('# Title'), 3).fontSize!;

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.typeImeText('```');
    await tester.pumpAndSettle();

    expect(_styleAt(spanOf('# Title'), 3).fontSize, lessThan(heading));
  });

  testWidgets('only Ctrl and a tap open a link', (tester) async {
    final document = markdown('see [docs](https://a.b) now\n\nother');
    await pumpDocument(tester, document);
    final link = tester.tapPointIn(lineNodeOf(0), 6);

    await tester.tapAt(link);
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();
    expect(document.links, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tapAt(link);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(document.links, ['https://a.b']);
  });

  testWidgets('an empty document says Untitled until typed in', (tester) async {
    final document = markdown('');
    await pumpDocument(tester, document);
    expect(find.text('Untitled'), findsOneWidget);

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.typeImeText('Idea');

    expect(find.text('Untitled'), findsNothing);
    expect(document.text, 'Idea');
  });

  testWidgets('pasted Windows line breaks make lines', (tester) async {
    final document = markdown('');
    await pumpDocument(tester, document);
    tester.clipboardHolds('a\r\nb\rc');

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.pressCtlV();
    await tester.pumpAndSettle();

    expect(document.text, 'a\nb\nc');
  });

  testWidgets('typing after a click away and back is a new undo step', (
    tester,
  ) async {
    final document = markdown('ab');
    await pumpDocument(tester, document);
    await tester.caretIn(lineNodeOf(0), 2);
    await tester.typeImeText('cd');

    await tester.caretIn(lineNodeOf(0), 0);
    await tester.caretIn(lineNodeOf(0), 4);
    await tester.typeImeText('e');
    document.undo();
    await tester.pumpAndSettle();

    expect(document.text, 'abcd');
  });

  testWidgets('a paste is an undo step of its own', (tester) async {
    final document = markdown('a');
    await pumpDocument(tester, document);
    tester.clipboardHolds('bc');
    await tester.caretIn(lineNodeOf(0), 1);
    await tester.typeImeText('x');

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    await tester.typeImeText('y');
    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'axbc');

    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'ax');
  });

  testWidgets('a paste over a selected word is one undo step', (tester) async {
    final document = markdown('buy milk');
    await pumpDocument(tester, document);
    tester.clipboardHolds('eggs');
    await tester.selectWordIn(lineNodeOf(0), 5);

    await tester.pressCtlV();
    await tester.pumpAndSettle();
    expect(document.text, 'buy eggs');

    document.undo();
    await tester.pumpAndSettle();
    expect(document.text, 'buy milk');
  });

  testWidgets('keypad keys move the caret with NumLock off', (tester) async {
    final document = markdown('buy milk');
    await pumpDocument(tester, document);

    await tester.caretIn(lineNodeOf(0), 5);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad4);
    await tester.typeImeText('x');

    expect(document.text, 'buy xmilk');
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('a change from elsewhere shows right away', (tester) async {
    final document = markdown('a');
    await pumpDocument(tester, document);

    document.changeElsewhere('a\nb');
    await tester.pumpAndSettle();

    expect(SuperEditorInspector.findDocument()!.nodeCount, 2);
    expect(document.edits, isEmpty);
  });
}

/// The style of the character at [offset] in [text].
TextStyle _styleAt(InlineSpan text, int offset) {
  final spans = <TextSpan>[];
  text.visitChildren((span) {
    if (span is TextSpan && (span.text?.isNotEmpty ?? false)) spans.add(span);
    return true;
  });
  final starts = spans.fold(<int>[0], (starts, span) {
    return [...starts, starts.last + span.text!.length];
  });
  final index = starts.lastIndexWhere((start) => start <= offset);
  return spans[index].style!;
}
