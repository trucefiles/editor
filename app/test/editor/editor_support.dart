import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/editor/note_document_controller.dart';
import 'package:truce_editor/notes/checked_items.dart';
import 'package:truce_editor/notes/note_mode.dart';
import 'package:truce_editor/notes/note_text.dart';

/// An open note's text in memory; records each edit.
final class FakeNoteText extends ChangeNotifier implements NoteText {
  FakeNoteText(this._text);

  String _text;
  final edits = <String>[];

  @override
  String get text => _text;

  @override
  void edit(String text) {
    edits.add(text);
    _text = text;
    notifyListeners();
  }

  /// The text changed elsewhere, e.g. on another device.
  void changeElsewhere(String text) {
    _text = text;
    notifyListeners();
  }
}

/// A view model of [text] in [mode].
NoteDocumentController documentOf(
  NoteText text, {
  NoteMode mode = NoteMode.visual,
  CheckedItems checkedItems = CheckedItems.doneSection,
  AddItemPlace addItems = AddItemPlace.top,
}) => NoteDocumentController(
  text,
  mode: mode,
  checkedItems: checkedItems,
  addItems: addItems,
);
