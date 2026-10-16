import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/markdown/markdown_view.dart';
import 'package:truce_editor/platform/link_opener.dart';

void main() {
  late _FakeLinkOpener links;

  setUp(() => links = _FakeLinkOpener());

  Future<void> show(WidgetTester tester, String markdown, {ThemeData? theme}) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: [linkOpenerProvider.overrideWithValue(links)],
          child: MaterialApp(
            theme: theme,
            home: Scaffold(body: MarkdownView(markdown)),
          ),
        ),
      );

  /// Taps the middle of [text] in the selectable paragraph holding it.
  Future<void> tapLink(WidgetTester tester, String text) async {
    final render = tester.allRenderObjects
        .whereType<RenderEditable>()
        .firstWhere((editable) => editable.plainText.contains(text));
    final start = render.plainText.indexOf(text);
    final box = render
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + text.length),
        )
        .first;
    await tester.tapAt(render.localToGlobal(box.toRect().center));
    await tester.pumpAndSettle();
  }

  testWidgets('shows Markdown without its markup', (tester) async {
    await show(tester, '# Title\n\nSome **bold** text.\n\n- [x] done');

    expect(find.text('Title'), findsOne);
    expect(find.text('Some bold text.'), findsOne);
    expect(find.byIcon(Icons.check_box), findsOne);
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets('checkboxes stand out in a dark theme', (tester) async {
    final dark = ThemeData(brightness: Brightness.dark);
    await show(tester, '- [ ] open', theme: dark);

    final box = tester.widget<Icon>(find.byIcon(Icons.check_box_outline_blank));
    expect(box.color, dark.colorScheme.primary);
  });

  testWidgets('keeps line breaks as typed', (tester) async {
    await show(tester, 'one\ntwo');

    expect(find.text('one\ntwo'), findsOne);
  });

  testWidgets('opens a web link on tap', (tester) async {
    await show(tester, 'See [the site](https://example.org/a) now.');

    await tapLink(tester, 'the site');

    expect(links.opened, [Uri.parse('https://example.org/a')]);
  });

  testWidgets('says so when no app opens a link', (tester) async {
    links.opens = false;
    await show(tester, '[site](https://example.org)');

    await tapLink(tester, 'site');

    expect(find.text('No app could open https://example.org'), findsOne);
  });

  testWidgets('opens no local or relative links', (tester) async {
    await show(tester, '[a](file:///bin/sh) [b](other.md)');

    await tapLink(tester, 'a');
    expect(find.text("Can't open file:///bin/sh"), findsOne);
    await tapLink(tester, 'b');
    expect(find.text("Can't open other.md"), findsOne);

    expect(links.opened, isEmpty);
  });
}

final class _FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];
  bool opens = true;

  @override
  Future<bool> open(Uri link) async {
    opened.add(link);
    return opens;
  }
}
