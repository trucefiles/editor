import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/note_editor_adapter.dart';

import '../editor_support.dart';

/// How the adapter tells the editor's phases how its nodes show.
void main() {
  test('a line node shows its line as the note has it now', () {
    final note = documentOf(FakeNoteText('a'));
    addTearDown(note.dispose);
    final adapter = NoteEditorAdapter(
      note,
      onRemoved: (_, _) {},
      onCaretPlaced: () {},
    );
    addTearDown(adapter.dispose);
    final node = adapter.editor.document.first.id;
    expect(adapter.viewOf(node)?.item, isNull);

    note.toList([note.lines.lines.first.id], ListKind.bullet);

    // Before the editor shows the change: styling must not lag behind.
    expect(adapter.viewOf(node)?.item?.kind, ListKind.bullet);
  });
}
