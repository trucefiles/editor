import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// A document in Read: formatted, and its links open as the Markdown
/// view opens them.
void main() {
  late List<Uri> opened;
  late bool opens;

  setUp(() {
    opened = [];
    opens = true;
  });

  Future<void> show(
    WidgetTester tester,
    String markdown, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ReadView(
              markdown,
              onLink: (url) => openMarkdownLink(
                url,
                open: (link) async {
                  opened.add(link);
                  return opens;
                },
                // A new hint replaces the one showing, as the page's do.
                hint: (message) => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(message))),
              ),
              images: const NoDocumentImages(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The texts shown, as the page shows them; icons (boxes) left out.
  Iterable<InlineSpan> texts(WidgetTester tester) => tester
      .elementList(
        find.descendant(
          of: find.byType(SelectionArea),
          matching: find.byType(RichText),
        ),
      )
      .where((text) => text.findAncestorWidgetOfExactType<Icon>() == null)
      .map((text) => (text.widget as RichText).text);

  Iterable<InlineSpan> spans(WidgetTester tester) =>
      texts(tester).expand((text) {
        final spans = <InlineSpan>[];
        text.visitChildren((span) {
          spans.add(span);
          return true;
        });
        return spans;
      });

  String shown(WidgetTester tester) =>
      texts(tester).map((text) => text.toPlainText()).join('\n');

  /// Taps the link that shows [text].
  Future<void> tapLink(WidgetTester tester, String text) async {
    final link = spans(tester)
        .whereType<TextSpan>()
        .firstWhere((span) => span.text == text && span.recognizer != null);
    (link.recognizer! as TapGestureRecognizer).onTap!();
    await tester.pumpAndSettle();
  }

  testWidgets('shows Markdown without its markup', (tester) async {
    await show(tester, '# Title\n\nSome **bold** text.\n\n- [x] done');

    expect(shown(tester), contains('Title'));
    expect(shown(tester), contains('Some bold text.'));
    expect(shown(tester), isNot(contains('#')));
    // The renderer's own checkbox, not the editors' marker.
    expect(find.byIcon(Icons.check_box), findsOne);
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('draws checkboxes in the theme color, also in dark mode', (
    tester,
  ) async {
    final dark = ThemeData(brightness: Brightness.dark);
    await show(tester, '- [x] done\n- [ ] open', theme: dark);

    for (final icon in [Icons.check_box, Icons.check_box_outline_blank]) {
      expect(
        tester.widget<Icon>(find.byIcon(icon)).color,
        dark.colorScheme.primary,
      );
    }
  });

  testWidgets('lays out small text on touch, items wider apart', (
    tester,
  ) async {
    await pumpDocument(
      tester,
      TestDocument('Para\n\nPara\n\n- [ ] a\n- [x] b', mode: EditMode.read),
      theme: ThemeData(materialTapTargetSize: MaterialTapTargetSize.padded),
      around: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(0.8)),
        child: child!,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Para', findRichText: true), findsNWidgets(2));
  });

  testWidgets('joins lines without a blank line between them', (tester) async {
    await show(tester, 'one\ntwo');

    expect(shown(tester), 'one two');
  });

  testWidgets('shows checked items in their place', (tester) async {
    await show(tester, '- [x] a\n- [ ] b');

    expect(shown(tester), 'a\nb');
  });

  testWidgets('leaves front matter out', (tester) async {
    await show(tester, '---\ntitle: x\n---\nbody');

    expect(shown(tester), 'body');
  });

  testWidgets('opens a web link on tap', (tester) async {
    await show(tester, 'See [the site](https://example.org/a) now.');

    await tapLink(tester, 'the site');

    expect(opened, [Uri.parse('https://example.org/a')]);
  });

  testWidgets('says so when no app opens a link', (tester) async {
    opens = false;
    await show(tester, '[site](https://example.org)');

    await tapLink(tester, 'site');

    expect(find.text('No app could open https://example.org'), findsOne);
  });

  testWidgets('opens a link written with www. but no scheme as https', (
    tester,
  ) async {
    await show(tester, '[site](www.example.org/a) [notes](notes.md)');

    await tapLink(tester, 'site');
    await tapLink(tester, 'notes');

    expect(opened, [Uri.parse('https://www.example.org/a')]);
    expect(find.text("Can't open notes.md"), findsOne);
  });

  testWidgets('opens no local or relative links', (tester) async {
    await show(tester, '[a](file:///bin/sh) [b](other.md)');

    await tapLink(tester, 'a');
    expect(find.text("Can't open file:///bin/sh"), findsOne);
    await tapLink(tester, 'b');
    expect(find.text("Can't open other.md"), findsOne);

    expect(opened, isEmpty);
  });

  for (final brightness in Brightness.values) {
    testWidgets('a quote is tinted as Visual edit tints it, '
        '${brightness.name}', (tester) async {
      final theme = ThemeData(brightness: brightness);
      await show(tester, '> a quote', theme: theme);

      final tinted = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration ==
                BoxDecoration(color: DocumentTextStyles.quoteTint(theme)),
      );
      expect(tinted, findsOneWidget);
    });
  }
}
