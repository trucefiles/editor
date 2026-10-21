import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/markdown/markdown_links.dart';
import 'package:truce_editor/platform/link_opener.dart';

import '../editor_support.dart';

/// A note in Read: formatted, and its links open.
void main() {
  late _FakeLinkOpener links;

  setUp(() => links = _FakeLinkOpener());

  Future<void> show(WidgetTester tester, String markdown) async {
    final note = documentOf(FakeNoteText(markdown), mode: NoteMode.read);
    addTearDown(note.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [linkOpenerProvider.overrideWithValue(links)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => NoteEditorView(
                note,
                onRemoved: (_, _) {},
                onLink: (url) => openMarkdownLink(context, ref, url),
                images: (_) => null,
              ),
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
    expect(find.byIcon(Icons.check_box), findsOne);
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
