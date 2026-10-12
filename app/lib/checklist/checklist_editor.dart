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

  void toggle(int id) => _apply(_list.toggle(id));

  void setText(int id, String text) => _apply(_list.setText(id, text));

  /// Returns the id of the new item.
  int insertAfter(int id) {
    final (list, newId) = _list.insertAfter(id, '');
    _apply(list);
    return newId;
  }

  /// Returns the id of the new item.
  int append(String text) {
    final (list, newId) = _list.append(text);
    _apply(list);
    return newId;
  }

  void move(int id, {required int? beforeId}) =>
      _apply(_list.move(id, beforeId: beforeId));

  void indent(int id) => _apply(_list.indent(id));

  void outdent(int id) => _apply(_list.outdent(id));

  /// Returns the text before, for [undo].
  String remove(int id) => _applyUndoable(_list.remove(id));

  /// Returns the text before, for [undo].
  String clearDone() => _applyUndoable(_list.clearDone());

  /// Goes back to [text] returned by an earlier action.
  void undo(String text) => _apply(Checklist.parse(text));

  String _applyUndoable(Checklist list) {
    final before = _list.text;
    _apply(list);
    return before;
  }

  void _apply(Checklist list) {
    _list = list;
    _session.edit(list.text);
    notifyListeners();
  }

  void _onSessionChanged() {
    if (_session.text == _list.text) return;
    _list = Checklist.parse(_session.text);
    notifyListeners();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
