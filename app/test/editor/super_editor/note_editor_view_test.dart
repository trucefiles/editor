import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';

import '../editor_support.dart';

void main() {
  Future<NoteDocumentController> pumpEditor(
    WidgetTester tester,
    FakeNoteText text,
  ) async {
    final note = documentOf(text);
    addTearDown(note.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteEditorView(note, onRemoved: (_, _) {}, onLink: (_) {}),
        ),
      ),
    );
    return note;
  }

  testWidgets('typing in an item changes only its line', (tester) async {
    final text = FakeNoteText('# Shop\n- [ ] milk\n- [ ] eggs');
    await pumpEditor(tester, text);

    final document = SuperEditorInspector.findDocument()!;
    final milk = document.whereType<TaskNode>().first;
    await tester.placeCaretInComponent(
      milk.id,
      const TextNodePosition(offset: 4),
    );
    await tester.typeImeText(' oat');

    expect(text.text, '# Shop\n- [ ] milk oat\n- [ ] eggs');
  });
}
