import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../notes/note_text.dart';

/// Applies checklist actions to an open note. No UI.
///
/// Each action edits the [MarkdownLines] and hands the new text to the open
/// note's [NoteText], which saves it. When that text changes from
/// elsewhere, the checklist is parsed again.
final class ChecklistEditor extends ChangeNotifier {
  ChecklistEditor(this._note) : _list = MarkdownLines.parse(_note.text) {
    _note.addListener(_onNoteChanged);
  }

  final NoteText _note;
  MarkdownLines _list;

  MarkdownLines get list => _list;

  /// [sort]: also moves the item, see [MarkdownLines.toggleAndSort].
  void toggle(int id, {bool sort = false}) =>
      _apply(sort ? _list.toggleAndSort(id) : _list.toggle(id));

  /// See [MarkdownLines.sortChecked]; saves only if anything moved.
  void sortChecked() {
    final sorted = _list.sortChecked();
    if (sorted.text != _list.text) _apply(sorted);
  }

  void setText(int id, String text) => _apply(_list.setText(id, text));

  /// Returns the id of the new item.
  int insertAfter(int id) {
    final (list, newId) = _list.insertAfter(id, '');
    _apply(list);
    return newId;
  }

  /// Returns the id of the new item.
  int insertBefore(int id, String text) {
    final (list, newId) = _list.insertBefore(id, text);
    _apply(list);
    return newId;
  }

  /// Returns the id of the new item.
  int appendAfter(int id, String text) {
    final (list, newId) = _list.appendAfter(id, text);
    _apply(list);
    return newId;
  }

  /// Returns the id of the new item.
  int append(String text) {
    final (list, newId) = _list.append(text);
    _apply(list);
    return newId;
  }

  /// See [MarkdownLines.removeLine].
  void removeLine(int id) => _apply(_list.removeLine(id));

  /// See [MarkdownLines.join].
  void join(int id, {required int into}) => _apply(_list.join(id, into: into));

  void move(int id, {required int? beforeId}) =>
      _apply(_list.move(id, beforeId: beforeId));

  /// [hidden]: lines the UI does not show above the item, see
  /// [MarkdownLines.indent].
  void indent(int id, {Set<int> hidden = const {}}) =>
      _apply(_list.indent(id, hidden: hidden));

  void outdent(int id) => _apply(_list.outdent(id));

  /// Returns how to [undo] it.
  ChecklistUndo remove(int id) => _applyUndoable(_list.remove(id));

  /// Returns how to [undo] it.
  ChecklistUndo clearDone() => _applyUndoable(_list.clearDone());

  /// Goes back to before the action that returned [undo]; returns whether
  /// it did. Does nothing once the checklist changed since, here or
  /// elsewhere: going back would drop that change.
  bool undo(ChecklistUndo undo) {
    if (_list.text != undo.after) return false;
    _apply(_list.reparse(undo.before));
    return true;
  }

  ChecklistUndo _applyUndoable(MarkdownLines list) {
    final before = _list.text;
    _apply(list);
    return (before: before, after: list.text);
  }

  void _apply(MarkdownLines list) {
    _list = list;
    _note.edit(list.text);
    notifyListeners();
  }

  void _onNoteChanged() {
    if (_note.text == _list.text) return;
    _list = _list.reparse(_note.text);
    notifyListeners();
  }

  @override
  void dispose() {
    _note.removeListener(_onNoteChanged);
    super.dispose();
  }
}

/// The text before and after an action, for [ChecklistEditor.undo].
typedef ChecklistUndo = ({String before, String after});
