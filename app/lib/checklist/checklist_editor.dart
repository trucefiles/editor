import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../notes/note_edit_session.dart';

/// Applies checklist actions to an open note. No UI.
///
/// Each action edits the [Checklist] and hands the new text to the
/// [NoteEditSession], which saves it. When the session's text changes from
/// elsewhere, the checklist is parsed again.
final class ChecklistEditor extends ChangeNotifier {
  ChecklistEditor(this._session) : _list = Checklist.parse(_session.text) {
    _session.addListener(_onSessionChanged);
  }

  final NoteEditSession _session;
  Checklist _list;

  Checklist get list => _list;

  /// [sort]: also moves the item, see [Checklist.toggleAndSort].
  void toggle(int id, {bool sort = false}) =>
      _apply(sort ? _list.toggleAndSort(id) : _list.toggle(id));

  /// See [Checklist.sortChecked]; saves only if anything moved.
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

  /// See [Checklist.removeLine].
  void removeLine(int id) => _apply(_list.removeLine(id));

  /// See [Checklist.join].
  void join(int id, {required int into}) => _apply(_list.join(id, into: into));

  void move(int id, {required int? beforeId}) =>
      _apply(_list.move(id, beforeId: beforeId));

  /// [hidden]: lines the UI does not show above the item, see
  /// [Checklist.indent].
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

  ChecklistUndo _applyUndoable(Checklist list) {
    final before = _list.text;
    _apply(list);
    return (before: before, after: list.text);
  }

  void _apply(Checklist list) {
    _list = list;
    _session.edit(list.text);
    notifyListeners();
  }

  void _onSessionChanged() {
    if (_session.text == _list.text) return;
    _list = _list.reparse(_session.text);
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}

/// The text before and after an action, for [ChecklistEditor.undo].
typedef ChecklistUndo = ({String before, String after});
