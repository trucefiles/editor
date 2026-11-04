import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart' show TextNode;
import 'package:truce_editor_test_support/truce_editor_test_support.dart';

/// The toolbar shows what is on where the caret is.
void main() {
  /// Whether the button labeled [label] shows pressed.
  bool pressed(WidgetTester tester, String label) => tester
      .widget<IconButton>(
        find.ancestor(
          of: find.byTooltip(label),
          matching: find.byType(IconButton),
        ),
      )
      .isSelected!;

  const labels = [
    'Bold (Ctrl+B)',
    'Italic (Ctrl+I)',
    'Link (Ctrl+K)',
    'Heading',
    'Checklist (Ctrl+Shift+9)',
    'Bulleted list (Ctrl+Shift+8)',
    'Numbered list (Ctrl+Shift+7)',
    'Quote',
  ];

  for (final (text, offset, on) in [
    ('**bold** *it* plain', 2, {'Bold (Ctrl+B)'}),
    ('**bold** *it* plain', 6, {'Italic (Ctrl+I)'}),
    ('**bold** *it* plain', 12, <String>{}),
    ('a [link](https://x.io)', 4, {'Link (Ctrl+K)'}),
    ('# Title', 2, {'Heading'}),
    ('- [ ] milk', 2, {'Checklist (Ctrl+Shift+9)'}),
    ('- milk', 2, {'Bulleted list (Ctrl+Shift+8)'}),
    ('1. milk', 2, {'Numbered list (Ctrl+Shift+7)'}),
    ('> quoted', 2, {'Quote'}),
  ]) {
    testWidgets('in "$text" at $offset, $on show pressed', (tester) async {
      await pumpDocument(tester, TestDocument(text));
      await tester.caretIn(nodeOf<TextNode>(), offset);

      expect({
        for (final label in labels)
          if (pressed(tester, label)) label,
      }, on);
    });
  }

  testWidgets('Bold pressed at a caret shows pressed until typed', (
    tester,
  ) async {
    await pumpDocument(tester, TestDocument('plain'));
    await tester.caretIn(nodeOf<TextNode>(), 5);
    expect(pressed(tester, 'Bold (Ctrl+B)'), isFalse);

    await tester.tap(find.byTooltip('Bold (Ctrl+B)'));
    await tester.pumpAndSettle();

    expect(pressed(tester, 'Bold (Ctrl+B)'), isTrue);
  });
}
