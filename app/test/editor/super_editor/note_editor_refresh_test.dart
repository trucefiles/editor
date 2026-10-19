import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/notes/note_mode.dart';
import 'package:truce_editor/refresh/ui/pull_to_refresh.dart';

import '../editor_support.dart';

/// Pulling an open note down refreshes, in every mode: the editor scrolls
/// inside the pull.
void main() {
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
              child: NoteEditorView(note, onRemoved: (_, _) {}, onLink: (_) {}),
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
