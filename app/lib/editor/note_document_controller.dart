import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import 'checked_items.dart';
import 'note_mode.dart';
import 'note_text.dart';

/// The open note as the editor shows it: its document, how it is arranged
/// in the current mode, the views an editor edits it through, and every
/// edit on it. No UI and no editor library.
///
/// Each edit changes the [MarkdownDocument] and hands the new text to the
/// open note's [NoteText], which saves it; edits never wait for a save.
/// When that text changes from elsewhere, it is read again, keeping the
/// ids of lines that stayed the same.
final class NoteDocumentController extends ChangeNotifier {
  NoteDocumentController(
    this._note, {
    required this._mode,
    required this._checkedItems,
    required this._addItems,
  }) : _document = MarkdownDocument.parse(_note.text) {
    _entries = _arrangement.of(_document);
    _note.addListener(_onNoteChanged);
  }

  final NoteText _note;
  MarkdownDocument _document;
  NoteMode _mode;
  CheckedItems _checkedItems;
  AddItemPlace _addItems;
  late List<DisplayEntry> _entries;

  /// Lists, by their first line, whose "Done" section is collapsed.
  final _collapsed = <LineId>{};

  /// Tables, by their first line, shown as their text.
  final _raw = <LineId>{};

  MarkdownDocument get document => _document;

  NoteMode get mode => _mode;

  CheckedItems get checkedItems => _checkedItems;

  /// What the editor shows, in display order.
  List<DisplayEntry> get entries => _entries;

  Arrangement get _arrangement => switch (_mode) {
    NoteMode.visual => Arrangement.blocks(
      doneSection: _checkedItems.shownApart,
      collapsed: _collapsed,
      addItems: _addItems,
      raw: _raw,
    ),
    NoteMode.markdown || NoteMode.read => const Arrangement.lines(),
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
      final sorted = _document.sortChecked();
      if (sorted.text != _document.text) return _apply(sorted);
    }
    _rearrange();
  }

  /// How [entry] shows to edit its text, with the caret in [caretLine];
  /// `null` for an entry that shows no text of the note (a heading or
  /// button).
  EditView? viewOf(DisplayEntry entry, {LineId? caretLine}) => switch (entry) {
    LeafEntry(:final leaf) || TableEntry(:final leaf) => LeafView.of(
      _document,
      _document.leafById(leaf)!,
      caretLine: caretLine,
    ),
    LineEntry(:final line) => RawLineView.of(
      _document,
      _document.lineOf(line)!,
    ),
    DoneHeadingEntry() || AddItemEntry() => null,
  };

  /// See [TextEdits.replaceText].
  LineCaret replaceText(
    ViewPlace from,
    ViewPlace to,
    String text, {
    Iterable<EditView> removed = const [],
  }) => _applyAt(_document.replaceText(from, to, text, removed: removed));

  /// Enter at [offset] in [view]: see [KeyEdits.enter]; in a line as it
  /// is in the file, a new line.
  LineCaret enter(EditView view, int offset) => _applyAt(switch (view) {
    LeafView() => _document.enter(
      view,
      offset,
      shownBelow: _shownBelow(view.id),
    ),
    RawLineView() => _newLine(view, offset),
  });

  /// A line break at [offset] in [view]: see [KeyEdits.lineBreak]; in a
  /// line as it is in the file, a new line.
  LineCaret lineBreak(EditView view, int offset) => _applyAt(switch (view) {
    LeafView() => _document.lineBreak(view, offset),
    RawLineView() => _newLine(view, offset),
  });

  (MarkdownDocument, LineCaret) _newLine(EditView view, int offset) {
    final place = (view: view, offset: offset);
    return _document.replaceText(place, place, '\n');
  }

  /// See [KeyEdits.joinBackward]; `null` if nothing changed, else where
  /// the caret goes, if anywhere in particular.
  ({LineCaret? caret})? joinBackward(EditView view, EditView? above) =>
      _applyJoin(_document.joinBackward(view, above));

  /// See [KeyEdits.joinForward], with the result of [joinBackward].
  ({LineCaret? caret})? joinForward(EditView view, EditView? below) =>
      _applyJoin(_document.joinForward(view, below));

  ({LineCaret? caret})? _applyJoin((MarkdownDocument, LineCaret?)? joined) {
    if (joined == null) return null;
    final (document, caret) = joined;
    _apply(document);
    return (caret: caret);
  }

  /// Checks or unchecks the checkbox [item]; with checked items moved to
  /// the end, it moves there too (see [ItemEdits.toggleAndSort]).
  void toggle(LineId item) => _apply(
    _checkedItems == CheckedItems.toEnd
        ? _document.toggleAndSort(item)
        : _document.toggle(item),
  );

  /// Folds or unfolds the "Done" section of the list [list].
  void toggleCollapsed(LineId list) {
    if (!_collapsed.remove(list)) _collapsed.add(list);
    _rearrange();
  }

  /// Shows the table whose first line is [leaf] as its text.
  void showRaw(LineId leaf) {
    _raw.add(leaf);
    _rearrange();
  }

  /// Adds an empty item where [button] says, of the kind of the item it
  /// adds next to; returns its line.
  LineId addItem(AddItemEntry button) {
    final (document, id) = _document.addItem(
      _document.outline.itemOf(button.anchor)!.kind,
      anchor: button.anchor,
      before: button.before,
    );
    _apply(document);
    return id;
  }

  /// See [ListConversion.toList]; returns the added item's line, if any.
  LineId? toList(List<LineId> lines, ListKind kind) {
    final (converted, added) = _document.toList(lines, kind);
    _apply(converted);
    return added;
  }

  /// See [ItemEdits.moveNextTo].
  void move(LineId item, {required LineId target, required bool below}) =>
      _apply(_document.moveNextTo(item, target: target, below: below));

  /// Indents the item [item] under the item shown above it.
  void indent(LineId item) =>
      _apply(_document.indent(item, hidden: _hiddenAbove(item)));

  void outdent(LineId item) => _apply(_document.outdent(item));

  /// The first line of the text shown right below the leaf [leaf]:
  /// `null` if what shows below is no text of the note, or nothing.
  LineId? _shownBelow(LineId leaf) {
    final index = _entries.indexWhere(
      (entry) => entry is LeafEntry && entry.leaf == leaf,
    );
    return switch (_entries.elementAtOrNull(index + 1)) {
      LeafEntry(:final leaf) || TableEntry(:final leaf) => leaf,
      _ => null,
    };
  }

  /// Every line but those of the text shown above the item [item] in its
  /// part of the display: up to the nearest heading or button above.
  Set<LineId> _hiddenAbove(LineId item) {
    final leaf = _document.leafOf(item).id;
    final above = _entries
        .takeWhile((entry) => !(entry is LeafEntry && entry.leaf == leaf))
        .toList()
        .reversed
        .takeWhile((entry) => entry is LeafEntry || entry is TableEntry)
        .expand(
          (entry) => switch (entry) {
            LeafEntry(:final leaf) || TableEntry(:final leaf) =>
              _document.leafById(leaf)!.lines.map((line) => line.id),
            _ => const <LineId>[],
          },
        )
        .toSet();
    return {
      for (final line in _document.lines)
        if (!above.contains(line.id)) line.id,
    };
  }

  /// Returns how to [undo] it.
  EditUndo remove(LineId item) => _applyUndoable(_document.remove(item));

  /// Returns how to [undo] it.
  EditUndo clearDone() => _applyUndoable(_document.clearDone());

  /// Goes back to before the action that returned [undo]; returns whether
  /// it did. Does nothing once the note changed since, here or elsewhere:
  /// going back would drop that change.
  bool undo(EditUndo undo) {
    if (_document.text != undo.after) return false;
    _apply(_document.reparse(undo.before));
    return true;
  }

  EditUndo _applyUndoable(MarkdownDocument document) {
    final before = _document.text;
    _apply(document);
    return (before: before, after: document.text);
  }

  LineCaret _applyAt((MarkdownDocument, LineCaret) edit) {
    final (document, caret) = edit;
    _apply(document);
    return caret;
  }

  void _apply(MarkdownDocument document) {
    final changed = document.text != _document.text;
    _document = document;
    if (changed) _note.edit(document.text);
    _rearrange();
  }

  void _rearrange() {
    _entries = _arrangement.of(_document);
    notifyListeners();
  }

  void _onNoteChanged() {
    if (_note.text == _document.text) return;
    _document = _document.reparse(_note.text);
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
