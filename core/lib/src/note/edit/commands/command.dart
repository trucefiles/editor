/// The commands of Visual edit: every user action that changes a note.
/// Each is a pure function of the shown note; [run] runs one.
library;

import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'heading.dart';
import 'indent.dart';
import 'items.dart';
import 'remove_frame.dart';
import 'set_frame.dart';
import 'split_block.dart';
import 'text_commands.dart';

export 'set_frame.dart' show FrameKind;

/// One user action, with the places it acts on.
sealed class Command {
  const Command();
}

/// Types [text], literal, at [at] in [formatting] (the typing style).
final class InsertText extends Command {
  const InsertText(this.at, this.text, this.formatting);

  final Place at;
  final String text;
  final Formatting formatting;
}

/// Replaces the text in [range], within one text place, by [text], as an
/// input method does (autocorrect, a suggestion, a composing word) and as
/// typing over a selection does: the text both share at their start and
/// end keeps its formatting; what changed takes the formatting of the
/// first character it replaced.
final class ReplaceText extends Command {
  const ReplaceText(this.range, this.text);

  final TextSelection range;
  final String text;
}

/// Removes the text in [range].
final class DeleteRange extends Command {
  const DeleteRange(this.range);

  final TextSelection range;
}

/// Puts a line break inside the text at [at].
final class LineBreak extends Command {
  const LineBreak(this.at);

  final Place at;
}

/// Enter at [at]: splits the block there (see `splitBlock`).
final class SplitBlock extends Command {
  const SplitBlock(this.at);

  final Place at;
}

/// Backspace at [slot]'s start: its text joins the text place above.
final class JoinWithPrevious extends Command {
  const JoinWithPrevious(this.slot);

  final Slot slot;
}

/// Delete at [slot]'s end: the text place below joins it.
final class JoinWithNext extends Command {
  const JoinWithNext(this.slot);

  final Slot slot;
}

/// Backspace at the start of [slot], the first text of its innermost
/// item or quote: that frame goes (see `removeFrame`).
final class RemoveFrame extends Command {
  const RemoveFrame(this.slot);

  final Slot slot;
}

/// Enter in [slot], an empty item's place at a list's top level: the
/// list ends there (see `leaveList`).
final class LeaveList extends Command {
  const LeaveList(this.slot);

  final Slot slot;
}

/// Tab in an item: it becomes a subitem of the item above.
final class Indent extends Command {
  const Indent(this.selection);

  final TextSelection selection;
}

/// Shift+Tab in an item: it goes one level out.
final class Outdent extends Command {
  const Outdent(this.selection);

  final TextSelection selection;
}

/// The heading button or shortcut at [at]: its text a heading of
/// [level], or a paragraph if `null`.
final class SetHeading extends Command {
  const SetHeading(this.at, this.level);

  final Place at;
  final int? level;
}

/// A tap on [item]'s box; [selection] stays.
final class Toggle extends Command {
  const Toggle(this.item, this.selection);

  final BlockId item;
  final Selection selection;
}

/// The row delete button on [item]: it goes with its subitems.
final class DeleteItem extends Command {
  const DeleteItem(this.item);

  final BlockId item;
}

/// The Add item button of [list]: a new empty item, last unless [first].
final class AddItem extends Command {
  const AddItem(this.list, {this.first = false});

  final BlockId list;
  final bool first;
}

/// A drop: [item] with its subitems right before [target], or after it
/// if [below]; [selection] stays.
final class MoveItem extends Command {
  const MoveItem(
    this.item,
    this.target, {
    required this.below,
    required this.selection,
  });

  final BlockId item;
  final BlockId target;
  final bool below;
  final Selection selection;
}

/// "Clear checked items now": the checked items at the top level of
/// [list]'s level, or of every list if `null`, go with their subitems.
final class ClearChecked extends Command {
  const ClearChecked(this.selection, {this.list});

  final Selection selection;
  final BlockId? list;
}

/// "Move checked items to end now", or checks settling: [items] (by
/// default every checked item at a list's top level) move to the end of
/// their lists; [selection] stays.
final class MoveToEnd extends Command {
  const MoveToEnd(this.selection, {this.items});

  final Selection selection;
  final List<BlockId>? items;
}

/// A frame button or shortcut: [kind] set on what [selection] covers,
/// or taken off where all of it has it (see `setFrame`).
final class SetFrame extends Command {
  const SetFrame(this.selection, this.kind);

  final TextSelection selection;
  final FrameKind kind;
}

/// [note] after [command], with the selection after it.
Edited run(ShownNote note, Command command) => commit(note, switch (command) {
  InsertText(:final at, :final text, :final formatting) => insertText(
    note,
    at,
    text,
    formatting,
  ),
  ReplaceText(:final range, :final text) => replaceText(note, range, text),
  DeleteRange(:final range) => deleteRange(note, range),
  LineBreak(:final at) => lineBreak(note, at),
  SplitBlock(:final at) => splitBlock(note, at),
  JoinWithPrevious(:final slot) => joinWithPrevious(note, slot),
  JoinWithNext(:final slot) => joinWithNext(note, slot),
  RemoveFrame(:final slot) => removeFrame(note, slot),
  LeaveList(:final slot) => leaveList(note, slot),
  Indent(:final selection) => indent(note, selection),
  Outdent(:final selection) => outdent(note, selection),
  SetHeading(:final at, :final level) => setHeading(note, at, level),
  SetFrame(:final selection, :final kind) => setFrame(note, selection, kind),
  Toggle(:final item, :final selection) => toggle(
    note,
    _item(note, item),
    selection,
  ),
  DeleteItem(:final item) => deleteItem(note, _item(note, item)),
  AddItem(:final list, :final first) => addItem(
    note,
    note.tree.blockOf(list)! as ListBlock,
    first: first,
  ),
  MoveItem(:final item, :final target, :final below, :final selection) =>
    moveItem(
      note,
      _item(note, item),
      _item(note, target),
      below: below,
      selection: selection,
    ),
  ClearChecked(:final selection, :final list) => clearItems(
    note,
    checkedItems(
      note,
      list: switch (list) {
        null => null,
        final id => note.tree.blockOf(id)! as ListBlock,
      },
    ),
    selection,
  ),
  MoveToEnd(:final selection, :final items) => moveToEnd(note, switch (items) {
    null => checkedItems(note),
    final ids => [for (final id in ids) _item(note, id)],
  }, selection),
});

ItemBlock _item(ShownNote note, BlockId id) =>
    note.tree.blockOf(id)! as ItemBlock;
