import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_robots/flutter_test_robots.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:super_editor/super_reader_test.dart';
import 'package:truce_editor/editor/note_mode.dart';

import '../editor_support.dart';
import 'editor_robot.dart';

/// How a note looks in the editor: theme colors, marks on the edited line,
/// quotes, compact lists and gaps.
void main() {
  bool shows(String text) =>
      find.text(text, findRichText: true).evaluate().isNotEmpty;

  group('marks of the edited line', () {
    const note = '**bold** one\nplain *it*';

    testWidgets('show on the line tapped, hidden on the others', (
      tester,
    ) async {
      await pumpNoteEditor(tester, FakeNoteText(note));

      await tester.caretIn(nodeOf<ParagraphNode>(index: 1), 2);
      expect(shows('plain *it*'), isTrue);
      expect(shows('bold one'), isTrue);

      await tester.caretIn(nodeOf<ParagraphNode>(), 2);
      expect(shows('**bold** one'), isTrue);
      expect(shows('plain it'), isTrue);
    });

    testWidgets('follow the caret moved by arrow keys', (tester) async {
      await pumpNoteEditor(tester, FakeNoteText(note));
      await tester.caretIn(nodeOf<ParagraphNode>(), 2);

      await tester.pressDownArrow();
      await tester.pumpAndSettle();

      expect(shows('plain *it*'), isTrue);
      expect(shows('bold one'), isTrue);
    });

    testWidgets('still follow the caret after the theme changes', (
      tester,
    ) async {
      final text = FakeNoteText(note);
      final document = await pumpNoteEditor(tester, text);
      // A new look rebuilds the editor's layout, phases and all.
      await showNoteEditor(tester, document, theme: ThemeData.dark());
      await tester.pumpAndSettle();

      await tester.caretIn(nodeOf<ParagraphNode>(index: 1), 2);

      expect(shows('plain *it*'), isTrue);
    });

    testWidgets('show in an item being edited', (tester) async {
      await pumpNoteEditor(tester, FakeNoteText('- [ ] **a** x\n- [ ] b'));

      await tester.caretIn(nodeOf<TaskNode>(), 2);

      expect(shows('**a** x'), isTrue);
    });
  });

  testWidgets('the caret takes the theme color', (tester) async {
    final document = await pumpNoteEditor(tester, FakeNoteText('a'));

    for (final theme in [ThemeData.light(), ThemeData.dark()]) {
      await showNoteEditor(tester, document, theme: theme);
      await tester.pumpAndSettle();
      final editor = tester.widget<SuperEditor>(find.byType(SuperEditor));
      final caret = editor.documentOverlayBuilders
          .whereType<DefaultCaretOverlayBuilder>()
          .single;
      expect(caret.caretStyle.color, theme.colorScheme.primary);
    }
  });

  Finder quoteBars() => find.byWidgetPredicate(
    (widget) => widget is Positioned && widget.width == 3,
  );

  testWidgets('a quote has a bar in Visual edit and Read, not in Markdown', (
    tester,
  ) async {
    const note = '> quoted\n**bold**';
    for (final (mode, bars) in [
      (NoteMode.visual, 1),
      (NoteMode.read, 1),
      (NoteMode.markdown, 0),
    ]) {
      // A view shows one mode for its life.
      await tester.pumpWidget(const SizedBox());
      await pumpNoteEditor(tester, FakeNoteText(note), mode: mode);
      await tester.pumpAndSettle();
      expect(quoteBars(), findsNWidgets(bars), reason: '$mode');
    }
  });

  testWidgets('a tap in a quote places the caret there', (tester) async {
    await pumpNoteEditor(tester, FakeNoteText('# T\n> said\nplain'));

    await tester.caretIn(nodeOf<ParagraphNode>(index: 1), 4);

    expect(
      SuperEditorInspector.findDocumentSelection()?.extent.nodeId,
      nodeOf<ParagraphNode>(index: 1),
    );
  });

  testWidgets('Read shows a run of blank lines as one small gap', (
    tester,
  ) async {
    await pumpNoteEditor(
      tester,
      FakeNoteText('a\n\n\n\nb'),
      mode: NoteMode.read,
    );
    await tester.pumpAndSettle();

    final nodes = SuperReaderInspector.findDocument()!.toList();
    expect(nodes, hasLength(3));
    final gap = tester.getSize(find.byType(TextComponent).at(1)).height;
    final line = tester.getSize(find.byType(TextComponent).first).height;
    expect(gap, lessThan(line));
  });

  testWidgets('list rows are about a text line high', (tester) async {
    for (final mode in [NoteMode.visual, NoteMode.read]) {
      await tester.pumpWidget(const SizedBox());
      await pumpNoteEditor(
        tester,
        FakeNoteText('- [ ] a\n- b\n1. c\nd'),
        mode: mode,
      );
      await tester.pumpAndSettle();
      final text = tester.getSize(find.byType(TextComponent).last).height;
      for (final row in find.byType(TextComponent).evaluate().take(3)) {
        final height = tester.getSize(find.byWidget(row.widget)).height;
        expect(height, lessThanOrEqualTo(text + 1), reason: '$mode');
      }
      final rowsTop =
          tester.getTopLeft(find.byType(TextComponent).at(1)).dy -
          tester.getTopLeft(find.byType(TextComponent).at(0)).dy;
      expect(rowsTop, lessThan(40), reason: '$mode: rows close together');
    }
  });

  testWidgets('Read has no drag handles or menus', (tester) async {
    await pumpNoteEditor(
      tester,
      FakeNoteText('- [ ] a\n- b'),
      mode: NoteMode.read,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    expect(find.byTooltip('Item actions'), findsNothing);
  });
}
