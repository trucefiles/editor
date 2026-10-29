import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// How a document looks in the editor: theme colors, marks hidden,
/// quotes, compact lists and gaps.
void main() {
  bool shows(String text) =>
      find.text(text, findRichText: true).evaluate().isNotEmpty;

  testWidgets('marks stay hidden in the block being edited', (tester) async {
    await pumpDocument(tester, TestDocument('**bold** one\n\nplain *it*'));

    await tester.caretIn(paragraphNodeOf(), 2);

    expect(shows('bold one'), isTrue);
    expect(shows('plain it'), isTrue);
  });

  testWidgets('the caret takes the theme color', (tester) async {
    final document = TestDocument('a');

    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await pumpDocument(tester, document, theme: theme);
      await tester.pumpAndSettle();
      final editor = tester.widget<SuperEditor>(find.byType(SuperEditor));
      final caret = editor.documentOverlayBuilders
          .whereType<DefaultCaretOverlayBuilder>()
          .single;
      expect(caret.caretStyle.color, theme.colorScheme.primary);
    }
  });

  testWidgets(
    'the touch handles take the theme color',
    (tester) async {
      final document = TestDocument('a');

      for (final theme in [ThemeData.light(), ThemeData.dark()]) {
        await pumpDocument(tester, document, theme: theme);
        await tester.pumpAndSettle();
        final context = tester.element(find.byType(SuperEditor));
        final color = switch (defaultTargetPlatform) {
          TargetPlatform.iOS => SuperEditorIosControlsScope.rootOf(
            context,
          ).handleColor,
          _ => SuperEditorAndroidControlsScope.rootOf(context).controlsColor,
        };
        expect(color, theme.colorScheme.primary);
      }
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.android,
      TargetPlatform.iOS,
    }),
  );

  Finder quoteBars() => find.byWidgetPredicate(
    (widget) => widget is Positioned && widget.width == 3,
  );

  testWidgets('a quote has a bar in Visual edit, not in Markdown', (
    tester,
  ) async {
    const text = '> quoted\n\n**bold**';
    for (final (mode, bars) in [(EditMode.visual, 1), (EditMode.markdown, 0)]) {
      // A view shows one mode for its life.
      await tester.pumpWidget(const SizedBox());
      await pumpDocument(tester, TestDocument(text, mode: mode));
      await tester.pumpAndSettle();
      expect(quoteBars(), findsNWidgets(bars), reason: '$mode');
    }
  });

  testWidgets('a line right below a quote shows inside it, joined', (
    tester,
  ) async {
    await pumpDocument(tester, TestDocument('> quoted\nmore\n\nafter'));
    await tester.pumpAndSettle();

    expect(quoteBars(), findsOneWidget);
    expect(shows('quoted more'), isTrue);
  });

  testWidgets("a quote's bar ends with its text, the gap below it", (
    tester,
  ) async {
    await pumpDocument(tester, TestDocument('> quoted\n\nafter'));
    await tester.pumpAndSettle();

    final bar = tester.getRect(quoteBars());
    final text = tester.getRect(find.text('quoted', findRichText: true));
    expect(bar.bottom, moreOrLessEquals(text.bottom, epsilon: 4));
    final after = tester.getRect(find.text('after', findRichText: true));
    expect(after.top - text.bottom, greaterThan(20), reason: 'a blank line');
  });

  testWidgets('the bar of a quote runs through the gaps between its rows', (
    tester,
  ) async {
    await pumpDocument(tester, TestDocument('> one\n>\n> two\n\nafter'));
    await tester.pumpAndSettle();

    final [first, second] = [
      for (final bar in quoteBars().evaluate())
        tester.getRect(find.byWidget(bar.widget)),
    ];
    final one = tester.getRect(find.text('one', findRichText: true));
    final two = tester.getRect(find.text('two', findRichText: true));
    expect(two.top - one.bottom, greaterThan(20), reason: 'a blank line');
    expect(second.top, moreOrLessEquals(first.bottom), reason: 'no break');
  });

  testWidgets('quotes and items nest as the file says', (tester) async {
    await pumpDocument(tester, TestDocument('> - [ ] a\n>   > b'));
    await tester.pumpAndSettle();

    expect(quoteBars(), findsNWidgets(3));
    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('numbered items count on from the first number', (tester) async {
    for (final mode in [EditMode.visual, EditMode.read]) {
      await tester.pumpWidget(const SizedBox());
      await pumpDocument(tester, TestDocument('3. a\n1. b', mode: mode));
      await tester.pumpAndSettle();
      expect(find.text('3.'), findsOneWidget, reason: '$mode');
      expect(find.text('4.'), findsOneWidget, reason: '$mode');
    }
  });

  testWidgets('a tap in a quote places the caret there', (tester) async {
    await pumpDocument(tester, TestDocument('# T\n> said\n\nplain'));

    await tester.caretIn(paragraphNodeOf(index: 1), 4);

    expect(
      SuperEditorInspector.findDocumentSelection()?.extent.nodeId,
      paragraphNodeOf(index: 1),
    );
  });

  /// The distance between the tops of the first two list rows, shown
  /// with [tapTargets] as the theme's tap target size.
  Future<double> rowPitch(
    WidgetTester tester,
    MaterialTapTargetSize tapTargets,
  ) async {
    await pumpDocument(
      tester,
      TestDocument('- [ ] a\n- b\n1. c\n\nd'),
      theme: ThemeData(materialTapTargetSize: tapTargets),
    );
    await tester.pumpAndSettle();
    final text = tester.getSize(find.byType(TextComponent).last).height;
    for (final row in find.byType(TextComponent).evaluate().take(3)) {
      final height = tester.getSize(find.byWidget(row.widget)).height;
      expect(height, lessThanOrEqualTo(text + 1));
    }
    return tester.getTopLeft(find.byType(TextComponent).at(1)).dy -
        tester.getTopLeft(find.byType(TextComponent).at(0)).dy;
  }

  testWidgets('list rows are about a text line high', (tester) async {
    expect(
      await rowPitch(tester, MaterialTapTargetSize.shrinkWrap),
      lessThan(40),
      reason: 'rows close together',
    );
  });

  testWidgets('on touch, list rows are a touch target apart', (tester) async {
    expect(
      await rowPitch(tester, MaterialTapTargetSize.padded),
      greaterThanOrEqualTo(kMinInteractiveDimension),
    );
  });

  testWidgets("on touch, an item's delete button is a touch target, as its "
      'handle', (tester) async {
    await pumpDocument(
      tester,
      TestDocument('- [ ] a\n- [ ] b'),
      theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded),
    );
    await tester.caretIn(checkboxNodeOf(), 0);

    final delete = tester.getSize(find.byTooltip('Delete item').first);
    final handle = tester.getSize(
      find
          .ancestor(
            of: find.byIcon(Icons.drag_indicator).first,
            matching: find.byType(MouseRegion),
          )
          .first,
    );
    expect(delete.width, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(delete.height, handle.height);
  });

  testWidgets('markers sit in the middle of their line of text', (
    tester,
  ) async {
    await pumpDocument(tester, TestDocument('- [ ] a\n- b\n\n1. c'));
    await tester.pumpAndSettle();

    for (final (marker, text) in [
      (find.byType(Checkbox), 'a'),
      (find.text('•'), 'b'),
      (find.text('1.'), 'c'),
    ]) {
      expect(
        tester.getCenter(marker).dy,
        moreOrLessEquals(
          tester.getCenter(find.text(text, findRichText: true)).dy,
          epsilon: 1,
        ),
        reason: text,
      );
    }
  });

  testWidgets('markers end the same gap before their text', (tester) async {
    await pumpDocument(tester, TestDocument('- [ ] a\n- b\n\n9. c\n10. d'));
    await tester.pumpAndSettle();

    // The box is drawn in the middle of the checkbox's tap area.
    final checkbox = find.byType(Checkbox);
    final boxEnd =
        tester.getTopRight(checkbox).dx -
        (tester.getSize(checkbox).width - Checkbox.width) / 2;
    final ends = [
      boxEnd,
      for (final marker in [find.text('•'), find.text('9.'), find.text('10.')])
        tester.getTopRight(marker).dx,
    ];
    for (final end in ends) {
      expect(end, moreOrLessEquals(ends.first, epsilon: 1));
    }
    final text = tester.getTopLeft(find.text('a', findRichText: true)).dx;
    expect(text - ends.first, moreOrLessEquals(12, epsilon: 1));
  });

  testWidgets('the format bar keeps clear of the bottom system edge', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPadding);
    await pumpDocument(tester, TestDocument('a'));
    await tester.pumpAndSettle();

    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final inset = 48 / tester.view.devicePixelRatio;
    expect(
      tester.getBottomLeft(find.byTooltip('Bold (Ctrl+B)')).dy,
      lessThanOrEqualTo(screen - inset),
    );
  });

  testWidgets('Read has no drag handles or delete buttons', (tester) async {
    await pumpDocument(
      tester,
      TestDocument('- [ ] a\n- b', mode: EditMode.read),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byTooltip('Delete item'), findsNothing);
  });
}
