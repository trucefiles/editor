import '../edit/shown/selection.dart';
import '../edit/shown/shown_document.dart';
import '../lines/line.dart';
import '../visible/formatting.dart';
import 'editor_contract.dart';

/// What the editor shows and how: the editor owner's state.
final class EditorState {
  const EditorState({
    required this.document,
    required this.selection,
    this.mode = EditMode.visual,
    this.checkedItems = CheckedItems.moveToEnd,
    this.revision = 0,
    this.typingStyle,
    this.raw,
  });

  final ShownDocument document;

  /// The selection in Visual edit; Markdown edit keeps its own caret.
  final Selection selection;

  final EditMode mode;
  final CheckedItems checkedItems;

  /// Counts the changes to what shows; inputs name the one they saw.
  final int revision;

  /// What text typed at a caret gets, once the user set it there; `null`
  /// while it follows the text at the caret.
  final Formatting? typingStyle;

  /// The block shown as raw text, if one is.
  final RawRegion? raw;

  EditorState copyWith({
    ShownDocument? document,
    Selection? selection,
    EditMode? mode,
    CheckedItems? checkedItems,
    int? revision,
    Object? typingStyle = _same,
    Object? raw = _same,
  }) => EditorState(
    document: document ?? this.document,
    selection: selection ?? this.selection,
    mode: mode ?? this.mode,
    checkedItems: checkedItems ?? this.checkedItems,
    revision: revision ?? this.revision,
    typingStyle: identical(typingStyle, _same)
        ? this.typingStyle
        : typingStyle as Formatting?,
    raw: identical(raw, _same) ? this.raw : raw as RawRegion?,
  );
}

/// Marks an [EditorState.copyWith] field left as it is.
const _same = Object();

/// A block shown as its raw lines, [first] to [last], with the caret
/// from [base] to [extent] in their text.
final class RawRegion {
  const RawRegion(
    this.first,
    this.last, {
    required this.base,
    required this.extent,
  });

  final LineId first;
  final LineId last;
  final int base;
  final int extent;
}
