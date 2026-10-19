import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../notes/checked_items.dart';
import '../notes/note_mode.dart';
import '../notes/note_text.dart';

/// The open note as the editor shows it: its lines, how they are arranged
/// in the current mode, and every edit on them. No UI and no editor
/// library.
///
/// Each edit changes the [MarkdownLines] and hands the new text to the
/// open note's [NoteText], which saves it; edits never wait for a save.
/// When that text changes from elsewhere, the lines are parsed again,
/// keeping the ids of lines that stayed the same.
final class NoteDocumentController extends ChangeNotifier {
  NoteDocumentController(
    this._note, {
    required this._mode,
    required this._checkedItems,
    required this._addItems,
  }) : _lines = MarkdownLines.parse(_note.text) {
    _entries = _arrangement.of(_lines);
    _note.addListener(_onNoteChanged);
  }

  final NoteText _note;
  MarkdownLines _lines;
  NoteMode _mode;
  CheckedItems _checkedItems;
  AddItemPlace _addItems;
  late List<DisplayEntry> _entries;

  /// Checklists, by their first line, whose "Done" section is collapsed.
  final _collapsed = <LineId>{};

  /// Tables and images, by their first line, shown as their lines.
  final _raw = <LineId>{};

  MarkdownLines get lines => _lines;

  NoteMode get mode => _mode;

  CheckedItems get checkedItems => _checkedItems;

  /// What the editor shows, in display order.
  List<DisplayEntry> get entries => _entries;

  Arrangement get _arrangement => switch (_mode) {
    NoteMode.markdown => const Arrangement(),
    NoteMode.visual => Arrangement(
      doneSection: _checkedItems.shownApart,
      collapsed: _collapsed,
      addItems: _addItems,
      drawBlocks: true,
      raw: _raw,
    ),
    NoteMode.read => Arrangement(
      doneSection: _checkedItems.shownApart,
      collapsed: _collapsed,
      drawBlocks: true,
    ),
  };

  set mode(NoteMode mode) {
    if (mode == _mode) return;
    _mode = mode;
    _raw.clear();
    _rearrange();
  }

  set addItems(AddItemPlace place) {
    if (place == _addItems) return;
    _addItems = place;
    _rearrange();
  }

  /// Takes the note's checked-items choice. One the user just [chose]
  /// moves items checked before too, if it moves checked items.
  void setCheckedItems(CheckedItems checkedItems, {bool chose = false}) {
    if (checkedItems == _checkedItems) return;
    _checkedItems = checkedItems;
    if (chose && checkedItems == CheckedItems.toEnd) {
      final sorted = _lines.sortChecked();
      if (sorted.text != _lines.text) return _apply(sorted);
    }
    _rearrange();
  }

  /// Applies one editor transaction; see [ApplyBlockEdits.applyEdits].
  /// With checked items moved to the end, an item the user checked or
  /// unchecked moves there too. Returns the ids of the added lines.
  List<LineId> applyEdits(List<BlockEdit> edits) {
    var (lines, added) = _lines.applyEdits(
      edits,
      shownBelow: linesShownBelow(_entries),
    );
    if (_checkedItems == CheckedItems.toEnd) {
      for (final id in _toggledIn(edits)) {
        lines = lines.sortToggled(id);
      }
    }
    _apply(lines);
    return added;
  }

  /// Lines of checkboxes whose box [edits] change.
  Iterable<LineId> _toggledIn(List<BlockEdit> edits) sync* {
    final byId = {for (final line in _lines.lines) line.id: line};
    for (final edit in edits) {
      if (edit case BlockChanged(:final id, block: ItemBlock(:final checked))
          when byId[id]?.isCheckbox == true && byId[id]?.isChecked != checked) {
        yield id;
      }
    }
  }

  /// Folds or unfolds the "Done" section of the list [list].
  void toggleCollapsed(LineId list) {
    if (!_collapsed.remove(list)) _collapsed.add(list);
    _rearrange();
  }

  /// Shows the table or image starting at line [first] as its lines.
  void showRaw(LineId first) {
    _raw.add(first);
    _rearrange();
  }

  /// Adds an empty item of [kind] where [buttons] say; returns its line.
  LineId addItem(AddItemEntry buttons, ListKind kind) {
    final (lines, id) = _lines.addItem(
      kind,
      anchor: buttons.anchor,
      before: buttons.before,
    );
    _apply(lines);
    return id;
  }

  /// See [StartList.startList]; returns the new item's line.
  LineId startList({LineId? at}) {
    final (lines, id) = _lines.startList(at: at);
    _apply(lines);
    return id;
  }

  /// See [MarkdownLines.moveNextTo].
  void move(LineId id, {required LineId target, required bool below}) =>
      _apply(_lines.moveNextTo(id, target: target, below: below));

  /// Indents the item [id] under the line shown above it.
  void indent(LineId id) => _apply(_lines.indent(id, hidden: _hiddenAbove(id)));

  void outdent(LineId id) => _apply(_lines.outdent(id));

  /// Every line but those shown above [id] in its part of the display:
  /// the lines up to the nearest heading, button, table or image above.
  Set<LineId> _hiddenAbove(LineId id) {
    final above = <LineId>{};
    for (final entry in _entries) {
      if (entry case LineEntry(id: final lineId)) {
        if (lineId == id) break;
        above.add(lineId);
      } else {
        above.clear();
      }
    }
    return {
      for (final line in _lines.lines)
        if (!above.contains(line.id)) line.id,
    };
  }

  /// Returns how to [undo] it.
  EditUndo remove(LineId id) => _applyUndoable(_lines.remove(id));

  /// Returns how to [undo] it.
  EditUndo clearDone() => _applyUndoable(_lines.clearDone());

  /// Goes back to before the action that returned [undo]; returns whether
  /// it did. Does nothing once the note changed since, here or elsewhere:
  /// going back would drop that change.
  bool undo(EditUndo undo) {
    if (_lines.text != undo.after) return false;
    _apply(_lines.reparse(undo.before));
    return true;
  }

  EditUndo _applyUndoable(MarkdownLines lines) {
    final before = _lines.text;
    _apply(lines);
    return (before: before, after: lines.text);
  }

  void _apply(MarkdownLines lines) {
    final changed = lines.text != _lines.text;
    _lines = lines;
    if (changed) _note.edit(lines.text);
    _rearrange();
  }

  void _rearrange() {
    _entries = _arrangement.of(_lines);
    notifyListeners();
  }

  void _onNoteChanged() {
    if (_note.text == _lines.text) return;
    _lines = _lines.reparse(_note.text);
    _rearrange();
  }

  @override
  void dispose() {
    _note.removeListener(_onNoteChanged);
    super.dispose();
  }
}

/// The text before and after an action, for
/// [NoteDocumentController.undo].
typedef EditUndo = ({String before, String after});
