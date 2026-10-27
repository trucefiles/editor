/// The editor owner's contract: what reaches it, what it decides, what it
/// leads to. One editor owner per open Markdown document; it holds what
/// the editor shows (the doc tree, the selection, the view state), runs
/// the commands, and sends the printed text to the file owner as the
/// save timing says (see `save_clock.dart`).
library;

import 'package:truce_core/truce_core.dart'
    show Asking, EffectId, FileInput, SecureReason, Ticket, ToEditor, Wait;

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

/// Markdown edit's text is now [text].
final class EditText extends ShownInput {
  const EditText(this.text, {required super.revision});

  final String text;
}

/// Undo the latest step of this editing session.
final class Undo extends ShownInput {
  const Undo({required super.revision});
}

/// Redo the step undone last.
final class Redo extends ShownInput {
  const Redo({required super.revision});
}

/// The document now reads [text] (a backup the user restored): one step,
/// which undo takes back.
final class ReplaceAll extends ShownInput {
  const ReplaceAll(this.text, {required super.revision});

  final String text;
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

/// Undo step [id], which [UndoOffered] told of, if it is still the
/// latest.
final class UndoStep extends EditorInput {
  const UndoStep(this.id);

  final int id;
}

/// What the file owner tells the editor.
final class FromFile extends EditorInput {
  const FromFile(this.message);

  final ToEditor message;
}

/// Keep the edits somewhere lasting now (the user leaves, hides or
/// closes): the editor sends its text, then asks the file owner to keep
/// it; the file owner's answer carries [ticket] back.
final class SecureEditor extends EditorInput implements Asking {
  const SecureEditor(this.ticket, this.reason);

  @override
  final Ticket ticket;
  final SecureReason reason;
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

/// What the file owner gets.
final class ToFile extends EditorEvent {
  const ToFile(this.input);

  final FileInput input;
}

/// The link dialog opens on [range].
final class AskLink extends EditorEvent {
  const AskLink(this.range);

  final TextSelection range;
}

/// Undo step [id] is one the user is offered to undo right away: [what]
/// it did.
final class UndoOffered extends EditorEvent {
  const UndoOffered(this.id, this.what);

  final int id;
  final OfferedUndo what;
}

/// What a step offered for undo did.
enum OfferedUndo {
  /// Removed items, or blocks without text.
  removal,

  /// Put a backup in place of the text ([ReplaceAll]).
  restore,
}

/// Undo step [id] could not be undone: the text changed since.
final class UndoRefused extends EditorEvent {
  const UndoRefused(this.id);

  final int id;
}

/// Undo reached the start of the history, which is there for [start].
final class HistoryEnd extends EditorEvent {
  const HistoryEnd(this.start);

  final HistoryStart start;
}

/// Why the undo history starts where it does.
enum HistoryStart {
  /// The document was opened there.
  opened,

  /// The document changed on another device (or elsewhere) there.
  changedElsewhere,

  /// A version was picked, or edits discarded, there.
  replacedHere,

  /// Older steps are not kept.
  limit,
}

// State.

/// What the editor shows and how: the editor owner's state.
final class EditorState {
  const EditorState({
    required this.content,
    required this.mode,
    required this.checkedItems,
    required this.revision,
    required this.unsent,
    this.canUndo = false,
    this.canRedo = false,
  });

  /// What shows: [MarkdownContent] in Markdown edit, else
  /// [FormattedContent].
  final EditorContent content;

  final EditMode mode;
  final CheckedItems checkedItems;

  /// Counts the changes to what shows; inputs name the one they saw.
  final int revision;

  /// Whether there are edits only in memory, not yet sent to be kept.
  final bool unsent;

  /// Whether [Undo] and [Redo] have a step to take.
  final bool canUndo;
  final bool canRedo;
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
