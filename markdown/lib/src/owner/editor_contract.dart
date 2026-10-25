/// The editor owner's contract: what reaches it, what it decides, what it
/// leads to. One editor owner per open Markdown document; it holds what
/// the editor shows (the tree, the selection, the view state), runs the
/// commands and tells the file owner of every text change.
library;

import 'package:truce_core/truce_core.dart'
    show FileInput, SecureReason, ToEditor;

import '../edit/commands/command.dart';
import '../edit/keys/key_map.dart';
import '../edit/shown/selection.dart';
import '../lines/line_change.dart';
import '../tree/blocks.dart';

/// How the document shows.
enum EditMode {
  /// Formatted, edited by commands.
  visual,

  /// Every character, edited as plain lines.
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

  /// Moved to the end of their list once a toggle settles.
  moveToEnd,
}

// Inputs.

sealed class EditorInput {
  const EditorInput();
}

/// An input from what the library shows at [revision]; refused if the
/// state moved on since.
sealed class ShownInput extends EditorInput {
  const ShownInput({required this.revision});

  final int revision;
}

/// [key] pressed in Visual edit.
final class Pressed extends ShownInput {
  const Pressed(this.key, {required super.revision});

  final EditKey key;
}

/// [text] typed over the selection, in the typing style.
final class Typed extends ShownInput {
  const Typed(this.text, {required super.revision});

  final String text;
}

/// [command] from the input method, a gesture, the toolbar or a menu.
final class Run extends ShownInput {
  const Run(this.command, {required super.revision});

  final Command command;
}

/// The user moved the caret or the selection to [selection].
final class CaretMoved extends ShownInput {
  const CaretMoved(this.selection, {required super.revision});

  final Selection selection;
}

/// A tap on [item]'s box.
final class ToggleItem extends ShownInput {
  const ToggleItem(this.item, {required super.revision});

  final BlockId item;
}

/// Markdown edit changed the lines.
final class EditLines extends ShownInput {
  const EditLines(this.change, {required super.revision});

  final LineChange change;
}

/// The open raw region now reads [text], its caret from [base] to
/// [extent] in it.
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

/// The caret moved within the open raw region.
final class RawCaretMoved extends ShownInput {
  const RawCaretMoved({
    required this.base,
    required this.extent,
    required super.revision,
  });

  final int base;
  final int extent;
}

/// A drag of [item] started: it no longer waits for its toggle to
/// settle.
final class DragStarted extends EditorInput {
  const DragStarted(this.item);

  final BlockId item;
}

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

  final BlockId list;
  final bool collapsed;
}

/// The undo of the removal [ItemsRemoved] told of.
final class UndoRemoval extends EditorInput {
  const UndoRemoval(this.id);

  final int id;
}

final class SettleTimerFired extends EditorInput {
  const SettleTimerFired(this.id);

  final int id;
}

/// What the file owner tells the editor.
final class FromFile extends EditorInput {
  const FromFile(this.message);

  final ToEditor message;
}

/// Keep the edits somewhere lasting now: the editor settles, then the
/// file owner keeps them.
final class SecureEditor extends EditorInput {
  const SecureEditor(this.reason);

  final SecureReason reason;
}

// Outputs.

sealed class EditorOutput {
  const EditorOutput();
}

/// What the file owner gets.
final class ToFile extends EditorOutput {
  const ToFile(this.input);

  final FileInput input;
}

/// Send [SettleTimerFired] with [id] after [delay].
final class StartSettleTimer extends EditorOutput {
  const StartSettleTimer(this.id, this.delay);

  final int id;
  final Duration delay;
}

/// The link dialog opens on [range].
final class AskLink extends EditorOutput {
  const AskLink(this.range);

  final TextSelection range;
}

/// A command removed items or blocks without text; [id] undoes it while
/// the text did not change since.
final class ItemsRemoved extends EditorOutput {
  const ItemsRemoved(this.id);

  final int id;
}

/// The undo [id] could not be made: the text changed since.
final class UndoRefused extends EditorOutput {
  const UndoRefused(this.id);

  final int id;
}
