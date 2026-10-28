/// The editor owner's contract: what reaches it, what it decides, what it
/// leads to. One editor owner per open Markdown document; it holds what
/// the editor shows (the doc tree, the selection, the view state), runs
/// the commands, and handles what every type's editor shares (core's
/// editor contract): the page's requests, undo, and sending the printed
/// text to the file owner as the save timing says.
library;

import 'package:truce_core/truce_core.dart'
    show EditorNotice, EditorRequest, EditorStatus, EffectId, Wait;

import '../doc/doc_nodes.dart';
import '../edit/commands/command.dart';
import '../edit/keys/key_map.dart';
import '../edit/selection.dart';
import '../view/rows.dart';
import '../visible/formatting.dart';

/// How the document shows.
enum EditMode {
  /// Formatted, edited by commands.
  visual,

  /// Every character, edited as plain text.
  markdown,

  /// Formatted, not editable.
  read,
}

/// How checked items show in Visual edit.
enum CheckedItems {
  /// Where they are in the file.
  inPlace,

  /// After the open items of their list, in a Done section; view only.
  doneSection,

  /// Moved to the end of their list once checked.
  moveToEnd,
}

/// What the editor owner handles: inputs anyone may send, and the results
/// of its effects.
sealed class EditorMessage {
  const EditorMessage();
}

// Inputs.

sealed class EditorInput extends EditorMessage {
  const EditorInput();
}

/// An input from what the editor shows at [revision]; dropped if the
/// state moved on since. In Visual edit, any but [EditRaw] and
/// [RawCaretMoved] closes an open raw block first.
sealed class ShownInput extends EditorInput {
  const ShownInput({required this.revision});

  final int revision;
}

/// [key] pressed in Visual edit.
final class Pressed extends ShownInput {
  const Pressed(this.key, {required super.revision});

  final EditKey key;
}

/// [text] typed over [over], the selection the input method or the
/// keyboard typed at: at the shown caret in the typing style, elsewhere
/// in the style of the text there. Text with line breaks goes in as a
/// paste of plain lines.
final class Typed extends ShownInput {
  const Typed(this.text, {required this.over, required super.revision});

  final String text;
  final TextSelection over;
}

/// [command] from the input method, a gesture, the toolbar or a menu;
/// never a [Toggle], which is a [ToggleItems].
final class Run extends ShownInput {
  const Run(this.command, {required super.revision});

  final Command command;
}

/// The user moved the caret or the selection to [selection].
final class CaretMoved extends ShownInput {
  const CaretMoved(this.selection, {required super.revision});

  final Selection selection;
}

/// [items]' boxes toggled, in the order tapped, once the view's wait
/// after the taps ended (see the plan's "checked items wait"); with "Move
/// to end" the checked ones move, together.
final class ToggleItems extends ShownInput {
  ToggleItems(List<NodeId> items, {required super.revision})
    : items = List.unmodifiable(items);

  final List<NodeId> items;
}

/// A tap or the caret on [block], a raw block: it opens as its raw text,
/// the caret at its end if [atEnd], else at its start.
final class OpenRawBlock extends ShownInput {
  const OpenRawBlock(
    this.block, {
    required this.atEnd,
    required super.revision,
  });

  final NodeId block;
  final bool atEnd;
}

/// The open raw block now reads [text], its caret from [base] to [extent]
/// in it.
final class EditRaw extends ShownInput {
  const EditRaw(
    this.text, {
    required this.base,
    required this.extent,
    required super.revision,
  });

  final String text;
  final int base;
  final int extent;
}

/// The caret moved within the open raw block.
final class RawCaretMoved extends ShownInput {
  const RawCaretMoved({
    required this.base,
    required this.extent,
    required super.revision,
  });

  final int base;
  final int extent;
}

/// Markdown edit's text is now [text]. A [pasted] text is an undo step
/// of its own, never part of the typing around it.
final class EditText extends ShownInput {
  const EditText(this.text, {required super.revision, this.pasted = false});

  final String text;
  final bool pasted;
}

/// The user moved the caret in Markdown edit.
final class TextCaretMoved extends ShownInput {
  const TextCaretMoved({required super.revision});
}

/// The document shows in [mode]; for Read, the text is sent first, so
/// the file owner's text is what shows.
final class SetMode extends EditorInput {
  const SetMode(this.mode);

  final EditMode mode;
}

/// The user chose how checked items show; nothing moves.
final class SetCheckedItems extends EditorInput {
  const SetCheckedItems(this.checkedItems);

  final CheckedItems checkedItems;
}

/// [list]'s Done section collapsed or opened.
final class SetCollapsed extends EditorInput {
  const SetCollapsed(this.list, {required this.collapsed});

  final NodeId list;
  final bool collapsed;
}

/// A request of the document page (see core's editor contract).
final class Request extends EditorInput {
  const Request(this.request);

  final EditorRequest request;
}

// Results.

sealed class EditorResult extends EditorMessage {
  const EditorResult();
}

/// The save timer [StartSaveTimer] started with [id] fired.
final class SaveTimerFired extends EditorResult {
  const SaveTimerFired(this.id);

  final EffectId id;
}

// Effects.

sealed class EditorEffect {
  const EditorEffect();
}

/// Fire [SaveTimerFired] with [id] after [delay].
final class StartSaveTimer extends EditorEffect
    implements Wait<SaveTimerFired> {
  const StartSaveTimer(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  SaveTimerFired get done => SaveTimerFired(id);
}

// Events.

sealed class EditorEvent {
  const EditorEvent();
}

/// What the document page hears (see core's editor contract).
final class Notice extends EditorEvent {
  const Notice(this.notice);

  final EditorNotice notice;
}

/// The link dialog opens on [range].
final class AskLink extends EditorEvent {
  const AskLink(this.range);

  final TextSelection range;
}

// State.

/// What the editor shows and how: the editor owner's state.
final class EditorState {
  const EditorState({
    required this.content,
    required this.mode,
    required this.checkedItems,
    required this.revision,
    this.status = const EditorStatus(),
  });

  /// What shows: [MarkdownContent] in Markdown edit, else
  /// [FormattedContent].
  final EditorContent content;

  final EditMode mode;
  final CheckedItems checkedItems;

  /// Counts the changes to what shows; inputs name the one they saw.
  final int revision;

  /// What it tells of the edits: whether some are only in memory, and
  /// what undo and redo can do.
  final EditorStatus status;
}

/// What shows: the doc tree, or the text Markdown edit edits.
sealed class EditorContent {
  const EditorContent();
}

/// The document formatted: its [view] rows, the [selection] in them, the
/// typing style the user set at the caret (`null` while it follows the
/// text there), and the raw block open, if one is.
final class FormattedContent extends EditorContent {
  const FormattedContent({
    required this.view,
    required this.selection,
    this.typingStyle,
    this.raw,
  });

  final ViewRows view;
  final Selection selection;
  final Formatting? typingStyle;
  final RawRegion? raw;
}

/// The document as the text Markdown edit edits; after an undo or redo,
/// the [caret] goes to the offset in [text] where it changed (`null`:
/// the caret stays where it is).
final class MarkdownContent extends EditorContent {
  const MarkdownContent(this.text, {this.caret});

  final String text;
  final int? caret;
}

/// The raw block [block] open as its raw [text], as typed so far, the
/// caret from [base] to [extent] in it.
final class RawRegion {
  const RawRegion(
    this.block,
    this.text, {
    required this.base,
    required this.extent,
  });

  final NodeId block;
  final String text;
  final int base;
  final int extent;
}
