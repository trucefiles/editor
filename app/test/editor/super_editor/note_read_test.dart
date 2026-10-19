import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_reader_test.dart';
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
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String shown() => SuperReaderInspector.findDocument()!
      .whereType<TextNode>()
      .map((node) => node.text.toPlainText())
      .join('\n');

  /// Taps the middle of [text] where the note shows it.
  Future<void> tapLink(WidgetTester tester, String text) async {
    final node = SuperReaderInspector.findDocument()!
        .whereType<TextNode>()
        .firstWhere((node) => node.text.toPlainText().contains(text));
    final start = node.text.toPlainText().indexOf(text);
    await SuperReaderRobot(tester).tapAtDocumentPosition(
      DocumentPosition(
        nodeId: node.id,
        nodePosition: TextNodePosition(offset: start + text.length ~/ 2),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows Markdown without its markup', (tester) async {
    await show(tester, '# Title\n\nSome **bold** text.\n\n- [x] done');

    expect(shown(), contains('Title'));
    expect(shown(), contains('Some bold text.'));
    expect(shown(), isNot(contains('#')));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('keeps line breaks as typed', (tester) async {
    await show(tester, 'one\ntwo');

    expect(shown(), 'one\ntwo');
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
