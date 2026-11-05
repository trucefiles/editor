import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart' show Redo;
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart'
    show CheckedItems, EditMode, Request;

/// Undo and redo scroll the document to where they act, if it is off
/// screen, in Visual and in Markdown edit.
void main() {
  final lines = [for (var line = 0; line < 60; line++) 'line $line'];

  /// The document's own scrollable: the one that scrolls farthest.
  ScrollPosition scrolled(WidgetTester tester) => tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .map((scrollable) => scrollable.position)
      .reduce((a, b) => a.maxScrollExtent >= b.maxScrollExtent ? a : b);

  /// Whether a line holding [text] shows within the screen.
  bool onScreen(WidgetTester tester, String text) {
    final found = find.textContaining(text, findRichText: true);
    if (found.evaluate().isEmpty) return false;
    final rect = tester.getRect(found.first);
    return rect.top >= 0 && rect.bottom <= tester.view.physicalSize.height;
  }

  testWidgets('Visual edit: undo and redo of a box tap at the end, which '
      'leaves no caret, bring it into view', (tester) async {
    tester.view.physicalSize = const Size(600, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final document = TestDocument(
      [for (final line in lines) '- [ ] $line'].join('\n'),
      checkedItems: CheckedItems.inPlace,
    );
    await pumpDocument(tester, document);
    final position = scrolled(tester);
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(document.text, endsWith('- [x] line 59'));

    for (final step in [
      document.undo,
      () => document.gate.external(const Request(Redo())),
    ]) {
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(onScreen(tester, 'line 59'), isFalse);
      step();
      await tester.pumpAndSettle();
      expect(onScreen(tester, 'line 59'), isTrue);
    }
    expect(document.text, endsWith('- [x] line 59'));
  });

  for (final mode in [EditMode.visual, EditMode.markdown]) {
    testWidgets('${mode.name}: undo and redo of an edit at the end, '
        'scrolled to the top meanwhile, bring it into view', (tester) async {
      tester.view.physicalSize = const Size(600, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final document = TestDocument(lines.join('\n\n'), mode: mode);
      await pumpDocument(tester, document);
      final position = scrolled(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      // In Markdown edit, the blank lines between are lines too.
      final last = mode == EditMode.visual
          ? paragraphNodeOf(index: 59)
          : lineNodeOf(118);
      await tester.caretIn(last, 7);
      await tester.typeImeText('!');
      // Undo and Redo come from the page's buttons, which the keyboard
      // focus need not be on.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      for (final (step, text) in [
        (document.undo, 'line 59'),
        (() => document.gate.external(const Request(Redo())), 'line 59!'),
      ]) {
        position.jumpTo(0);
        await tester.pumpAndSettle();
        expect(onScreen(tester, 'line 59'), isFalse);
        step();
        await tester.pumpAndSettle();
        expect(find.text(text, findRichText: true), findsOneWidget);
        expect(onScreen(tester, text), isTrue, reason: 'after $text');
      }
    });
  }
}
