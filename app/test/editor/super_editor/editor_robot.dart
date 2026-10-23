import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';
import 'package:super_editor/super_editor_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/checked_items.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/editor/super_editor/note_editor_view.dart';
import 'package:truce_editor/editor/super_editor/note_nodes.dart';

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
  await showNoteEditor(tester, note, onRemoved: onRemoved, onLink: onLink);
  return note;
}

/// Shows [note] in a [NoteEditorView] in [theme]; shown again, the same
/// view takes the new [theme].
Future<void> showNoteEditor(
  WidgetTester tester,
  NoteDocumentController note, {
  ThemeData? theme,
  void Function(String message, EditUndo undo)? onRemoved,
  void Function(String url)? onLink,
}) => tester.pumpWidget(
  MaterialApp(
    theme: theme,
    home: Scaffold(
      body: NoteEditorView(
        note,
        onRemoved: onRemoved ?? (_, _) {},
        onLink: onLink ?? (_) {},
        images: (_) => null,
      ),
    ),
  ),
);

/// The id of the [index]th node of type [T] in the editor.
String nodeOf<T extends DocumentNode>({int index = 0}) =>
    SuperEditorInspector.findDocument()!.whereType<T>().elementAt(index).id;

/// The item whose marker shows beside [node], if any.
ItemFrame? markedItemOf(DocumentNode node) =>
    switch (framesIn(node).whereType<ItemFrame>().lastOrNull) {
      final item? when item.showsMarker => item,
      _ => null,
    };

/// The id of the [index]th text node that starts a checkbox item.
String checkboxNodeOf({int index = 0}) =>
    _textNodeOf(index, (item) => item?.kind == ListKind.checkbox);

/// The id of the [index]th text node that starts a bullet or numbered
/// item.
String listItemNodeOf({int index = 0}) => _textNodeOf(
  index,
  (item) => item != null && item.kind != ListKind.checkbox,
);

/// The id of the [index]th text node that starts no item.
String paragraphNodeOf({int index = 0}) =>
    _textNodeOf(index, (item) => item == null);

String _textNodeOf(int index, bool Function(ItemFrame? item) test) =>
    SuperEditorInspector.findDocument()!
        .whereType<TextNode>()
        .where((node) => test(markedItemOf(node)))
        .elementAt(index)
        .id;

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
