import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/super_editor/note_editor_adapter.dart';

import '../editor_support.dart';

/// How the adapter keeps the editor's nodes showing the note.
void main() {
  test('each node shows the view of the note as it is now', () async {
    final note = documentOf(FakeNoteText('a'));
    addTearDown(note.dispose);
    final adapter = NoteEditorAdapter(
      note,
      onRemoved: (_, _) {},
      onCaretPlaced: () {},
    );
    addTearDown(adapter.dispose);
    final node = adapter.editor.document.first.id;
    expect(adapter.viewOf(node), isA<LeafView>());
    expect((adapter.viewOf(node)! as LeafView).frames, isEmpty);

    note.toList([note.document.lines.first.id], ListKind.bullet);
    await Future<void>.delayed(Duration.zero);

    final frames = (adapter.viewOf(node)! as LeafView).frames;
    expect(frames.single, isA<ItemFrame>());
    final shown = adapter.editor.document.getNodeById(node)! as TextNode;
    expect(shown.text.toPlainText(), 'a');
  });
}
