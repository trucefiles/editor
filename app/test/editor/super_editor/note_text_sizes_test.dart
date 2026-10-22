import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/note_mode.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// A note's text is as large in every mode: switching modes keeps its
/// size.
void main() {
  const note = '# Head\n\nplain words with `code` in them';

  /// The font size of the text [text] in the note shown in [mode].
  Future<double> sizeOf(
    WidgetTester tester,
    String text, {
    required NoteMode mode,
  }) async {
    final document = documentOf(FakeNoteText(note), mode: mode);
    addTearDown(document.dispose);
    await showNoteEditor(tester, document);
    await tester.pumpAndSettle();
    final sizes = [
      for (final element
          in find.byWidgetPredicate((widget) => widget is RichText).evaluate())
        ...spanSizes((element.widget as RichText).text, const TextStyle()),
    ];
    return sizes.firstWhere((entry) => entry.$1 == text).$2;
  }

  for (final (text, what) in [
    ('plain words with ', 'body text'),
    ('code', 'code'),
    ('Head', 'a heading'),
  ]) {
    testWidgets('$what is as large in Visual edit as in Read', (tester) async {
      expect(
        await sizeOf(tester, text, mode: NoteMode.visual),
        await sizeOf(tester, text, mode: NoteMode.read),
      );
    });
  }

  testWidgets('code is a little smaller than the text around it', (
    tester,
  ) async {
    for (final mode in [NoteMode.visual, NoteMode.read]) {
      final body = await sizeOf(tester, 'plain words with ', mode: mode);
      final code = await sizeOf(tester, 'code', mode: mode);
      expect(code, lessThan(body), reason: '$mode');
      expect(code, greaterThan(body * 0.8), reason: '$mode');
    }
  });
}

/// Each piece of plain text under [span] with its font size, styles
/// inherited from [inherited].
Iterable<(String, double)> spanSizes(InlineSpan span, TextStyle inherited) {
  final style = inherited.merge(span.style);
  return switch (span) {
    TextSpan(:final text, :final children) => [
      if (text != null && text.isNotEmpty) (text, style.fontSize ?? 14),
      for (final child in children ?? const <InlineSpan>[])
        ...spanSizes(child, style),
    ],
    _ => const [],
  };
}
