import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

import 'editor_robot.dart';

/// A document's text is as large in every mode: switching modes keeps its
/// size.
void main() {
  const text = '# Head\n\nplain words with `code` in them';

  /// The font size of [piece] in the document shown in [mode].
  Future<double> sizeOf(
    WidgetTester tester,
    String piece, {
    required EditMode mode,
  }) async {
    // A fresh view: one kept from before would show its own document.
    await tester.pumpWidget(const SizedBox());
    await pumpDocument(tester, TestDocument(text, mode: mode));
    await tester.pumpAndSettle();
    final sizes = [
      for (final element
          in find.byWidgetPredicate((widget) => widget is RichText).evaluate())
        ...spanSizes((element.widget as RichText).text, const TextStyle()),
    ];
    return sizes.firstWhere((entry) => entry.$1 == piece).$2;
  }

  for (final (text, what) in [
    ('plain words with ', 'body text'),
    ('code', 'code'),
    ('Head', 'a heading'),
  ]) {
    testWidgets('$what is as large in Visual edit as in Read', (tester) async {
      expect(
        await sizeOf(tester, text, mode: EditMode.visual),
        await sizeOf(tester, text, mode: EditMode.read),
      );
    });
  }

  testWidgets('code is a little smaller than the text around it', (
    tester,
  ) async {
    for (final mode in [EditMode.visual, EditMode.read]) {
      final body = await sizeOf(tester, 'plain words with ', mode: mode);
      final code = await sizeOf(tester, 'code', mode: mode);
      expect(code, lessThan(body), reason: '$mode');
      expect(code, greaterThan(body * 0.8), reason: '$mode');
    }
  });

  testWidgets('in Markdown edit, code is as large, so columns line up', (
    tester,
  ) async {
    expect(
      await sizeOf(tester, 'code', mode: EditMode.markdown),
      await sizeOf(tester, 'plain words with ', mode: EditMode.markdown),
    );
  });

  testWidgets('lines stand about as far apart in Read as in Visual edit', (
    tester,
  ) async {
    /// How far below 'a' the line 'b' of [text] starts, in [mode].
    Future<double> pitch(String text, EditMode mode) async {
      // A fresh view: one kept from before would show its own document.
      await tester.pumpWidget(const SizedBox());
      await pumpDocument(
        tester,
        TestDocument(text, mode: mode),
        // Desktop: on touch, item rows are taller in the editors only, to
        // be hit by a finger.
        theme: ThemeData(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      await tester.pumpAndSettle();
      double top(String text) =>
          tester.getTopLeft(find.text(text, findRichText: true)).dy;
      return top('b') - top('a');
    }

    for (final text in ['- a\n- b', 'a\n\nb', '# a\n\nb']) {
      final visual = await pitch(text, EditMode.visual);
      expect(
        await pitch(text, EditMode.read),
        closeTo(visual, visual * 0.15),
        reason: text,
      );
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
