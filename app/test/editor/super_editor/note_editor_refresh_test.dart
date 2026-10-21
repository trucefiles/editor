import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/refresh/ui/pull_to_refresh.dart';

import '../editor_support.dart';

/// Pulling an open note down refreshes, in every mode: the editor scrolls
/// inside the pull.
void main() {
  Future<int Function()> pumpPull(
    WidgetTester tester,
    String text,
    NoteMode mode,
  ) async {
    var refreshes = 0;
    final note = documentOf(FakeNoteText(text), mode: mode);
    addTearDown(note.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PullToRefresh(
            onRefresh: () async => refreshes++,
            child: NoteEditorView(
              note,
              onRemoved: (_, _) {},
              onLink: (_) {},
              images: (_) => null,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return () => refreshes;
  }

  testWidgets('in Read, a drag on the text scrolls the note, never refreshes', (
    tester,
  ) async {
    final refreshes = await pumpPull(
      tester,
      [for (final line in Iterable<int>.generate(60)) 'line $line']
          .join('\n\n'),
      NoteMode.read,
    );
    Finder line(int index) => find.text('line $index', findRichText: true);

    await tester.drag(line(5), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(line(0), findsNothing, reason: 'scrolled down');

    await tester.drag(line(15), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(refreshes(), 0);
  });

  for (final mode in NoteMode.values) {
    testWidgets('pulling down by touch refreshes in ${mode.name}', (
      tester,
    ) async {
      var refreshes = 0;
      final note = documentOf(FakeNoteText('- [ ] milk\neggs'), mode: mode);
      addTearDown(note.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PullToRefresh(
              onRefresh: () async => refreshes++,
              child: NoteEditorView(
                note,
                onRemoved: (_, _) {},
                onLink: (_) {},
                images: (_) => null,
              ),
            ),
          ),
        ),
      );

      await tester.fling(
        find.byType(NoteEditorView),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(refreshes, 1);
    });
  }
}
