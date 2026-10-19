import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/notes/checked_items.dart';
import 'package:truce_editor/notes/note_mode.dart';

import '../editor_support.dart';

/// Shows [text] in a [NoteEditorView] in [mode]; returns its view model.
Future<NoteDocumentController> pumpNoteEditor(
  WidgetTester tester,
  FakeNoteText text, {
  NoteMode mode = NoteMode.visual,
  CheckedItems checkedItems = CheckedItems.doneSection,
  void Function(String message, EditUndo undo)? onRemoved,
  void Function(String url)? onLink,
}) async {
  final note = documentOf(text, mode: mode, checkedItems: checkedItems);
  addTearDown(note.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NoteEditorView(
          note,
          onRemoved: onRemoved ?? (_, _) {},
          onLink: onLink ?? (_) {},
        ),
      ),
    ),
  );
  return note;
}

/// The id of the [index]th node of type [T] in the editor.
String nodeOf<T extends DocumentNode>({int index = 0}) =>
    SuperEditorInspector.findDocument()!.whereType<T>().elementAt(index).id;

/// A user's taps in the note editor.
extension NoteEditorRobot on WidgetTester {
  /// Where a finger taps the line [nodeId] at [offset]: the middle of the
  /// line. The library robot's own taps hit the line's top edge.
  Offset tapPointIn(String nodeId, int offset) {
    final layout = SuperEditorInspector.findDocumentLayout();
    final rect = layout.getRectForPosition(
      DocumentPosition(
        nodeId: nodeId,
        nodePosition: TextNodePosition(offset: offset),
      ),
    )!;
    return layout.getAncestorOffsetFromDocumentOffset(rect.center);
  }

  Future<void> caretIn(String nodeId, int offset) async {
    await tapAt(tapPointIn(nodeId, offset));
    await pump(kTapTimeout);
    await pumpAndSettle();
  }

  Future<void> selectWordIn(String nodeId, int offset) async {
    final point = tapPointIn(nodeId, offset);
    await tapAt(point);
    await pump(kTapMinTime + const Duration(milliseconds: 1));
    await tapAt(point);
    await pump(kTapTimeout);
    await pumpAndSettle();
  }
}
