/// The commands of Visual edit: every user action that changes a document.
/// Each is a pure function of the shown document; [run] runs one.
library;

import '../../tree/blocks.dart';
import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_document.dart';
import '../shown/slot.dart';
import 'heading.dart';
import 'indent.dart';
import 'items.dart';
import 'links.dart';
import 'over_range.dart';
import 'paste.dart';
import 'remove_block.dart';
import 'remove_frame.dart';
import 'set_frame.dart';
import 'split_block.dart';
import 'styles.dart';
import 'text_commands.dart';

export 'set_frame.dart' show FrameKind;

/// One user action, with the places it acts on.
sealed class Command {
  const Command();
}

/// A command that is one edit of the shown document.
sealed class EditCommand extends Command {
  const EditCommand();
}

/// Paste of plain [text] over [range], in [formatting] (the typing
/// style); see `paste`.
final class Paste extends Command {
  const Paste(this.range, this.text, this.formatting);

  final TextSelection range;
  final String text;
  final Formatting formatting;
}

/// Types [text], literal, at [at] in [formatting] (the typing style).
final class InsertText extends EditCommand {
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
final class ReplaceText extends EditCommand {
  const ReplaceText(this.range, this.text);

  final TextSelection range;
  final String text;
}

/// Removes the text in [range].
final class DeleteRange extends EditCommand {
  const DeleteRange(this.range);

  final TextSelection range;
}

/// Shift+Enter over [range]: its text replaced by a line break.
final class LineBreak extends Command {
  const LineBreak(this.range);

  final TextSelection range;
}

/// Enter over [range]: its text removed, then the block split at the
/// caret (see `splitBlock`).
final class SplitBlock extends Command {
  const SplitBlock(this.range);

  final TextSelection range;
}

/// Backspace at [slot]'s start: its text joins the text place above.
final class JoinWithPrevious extends EditCommand {
  const JoinWithPrevious(this.slot);

  final Slot slot;
}

/// Delete at [slot]'s end: the text place below joins it.
final class JoinWithNext extends EditCommand {
  const JoinWithNext(this.slot);

  final Slot slot;
}

/// Backspace at the start of [slot], the first text of its innermost
/// item or quote: that frame goes (see `removeFrame`).
final class RemoveFrame extends EditCommand {
  const RemoveFrame(this.slot);

  final Slot slot;
}

/// Enter in [slot], an empty item's place at a list's top level: the
/// list ends there (see `leaveList`).
final class LeaveList extends EditCommand {
  const LeaveList(this.slot);

  final Slot slot;
}

/// Tab in an item: it becomes a subitem of the item above.
final class Indent extends EditCommand {
  const Indent(this.selection);

  final TextSelection selection;
}

/// Shift+Tab in an item: it goes one level out.
final class Outdent extends EditCommand {
  const Outdent(this.selection);

  final TextSelection selection;
}

/// The heading button or shortcut at [at]: its text a heading of
/// [level], or a paragraph if `null`.
final class SetHeading extends EditCommand {
  const SetHeading(this.at, this.level);

  final Place at;
  final int? level;
}

/// A tap on [item]'s box; [selection] stays.
final class Toggle extends EditCommand {
  const Toggle(this.item, this.selection);

  final BlockId item;
  final Selection selection;
}

/// The row delete button on [item]: it goes with its subitems.
final class DeleteItem extends EditCommand {
  const DeleteItem(this.item);

  final BlockId item;
}

/// Backspace or Delete on [block], a selected rule: it goes.
final class RemoveBlock extends EditCommand {
  const RemoveBlock(this.block);

  final BlockId block;
}

/// The Add item button of [list]: a new empty item, last unless [first].
final class AddItem extends EditCommand {
  const AddItem(this.list, {this.first = false});

  final BlockId list;
  final bool first;
}

/// A drop: [item] with its subitems right before [target], or after it
/// if [below]; [selection] stays.
final class MoveItem extends EditCommand {
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
final class ClearChecked extends EditCommand {
  const ClearChecked(this.selection, {this.list});

  final Selection selection;
  final BlockId? list;
}

/// "Move checked items to end now", or checks settling: [items] (by
/// default every checked item at a list's top level) move to the end of
/// their lists; [selection] stays.
final class MoveToEnd extends EditCommand {
  const MoveToEnd(this.selection, {this.items});

  final Selection selection;
  final List<BlockId>? items;
}

/// A frame button or shortcut: [kind] set on what [selection] covers,
/// or taken off where all of it has it (see `setFrame`).
final class SetFrame extends EditCommand {
  const SetFrame(this.selection, this.kind);

  final TextSelection selection;
  final FrameKind kind;
}

/// A style button or shortcut: [format] toggled over [selection] (see
/// `toggleStyle`).
final class ToggleStyle extends EditCommand {
  const ToggleStyle(this.selection, this.format);

  final TextSelection selection;
  final TextFormat format;
}

/// The link dialog's OK: [range] showing [text] as a link to [url] (see
/// `setLink`).
final class SetLink extends EditCommand {
  const SetLink(this.range, this.text, this.url);

  final TextSelection range;
  final String text;
  final String url;
}

/// The link dialog's Remove: the link at [at] goes, its text stays.
final class RemoveLink extends EditCommand {
  const RemoveLink(this.at);

  final Place at;
}

/// [document] after [command], with the selection after it.
Edited run(ShownDocument document, Command command) => switch (command) {
  Paste(:final range, :final text, :final formatting) => paste(
    document,
    range,
    text,
    formatting,
  ),
  LineBreak(:final range) => overRange(document, range, lineBreak),
  SplitBlock(:final range) => overRange(document, range, splitBlock),
  final EditCommand command => commit(document, _edit(document, command)),
};

Edit _edit(ShownDocument document, EditCommand command) => switch (command) {
  InsertText(:final at, :final text, :final formatting) => insertText(
    document,
    at,
    text,
    formatting,
  ),
  ReplaceText(:final range, :final text) => replaceText(document, range, text),
  DeleteRange(:final range) => deleteRange(document, range),
  JoinWithPrevious(:final slot) => joinWithPrevious(document, slot),
  JoinWithNext(:final slot) => joinWithNext(document, slot),
  RemoveFrame(:final slot) => removeFrame(document, slot),
  LeaveList(:final slot) => leaveList(document, slot),
  Indent(:final selection) => indent(document, selection),
  Outdent(:final selection) => outdent(document, selection),
  SetHeading(:final at, :final level) => setHeading(document, at, level),
  SetFrame(:final selection, :final kind) => setFrame(
    document,
    selection,
    kind,
  ),
  SetLink(:final range, :final text, :final url) => setLink(
    document,
    range,
    text,
    url,
  ),
  RemoveLink(:final at) => removeLink(document, at),
  ToggleStyle(:final selection, :final format) => toggleStyle(
    document,
    selection,
    format,
  ),
  Toggle(:final item, :final selection) => toggle(
    document,
    _item(document, item),
    selection,
  ),
  DeleteItem(:final item) => deleteItem(document, _item(document, item)),
  RemoveBlock(:final block) => removeBlock(
    document,
    document.tree.blockOf(block)! as LeafBlock,
  ),
  AddItem(:final list, :final first) => addItem(
    document,
    document.tree.blockOf(list)! as ListBlock,
    first: first,
  ),
  MoveItem(:final item, :final target, :final below, :final selection) =>
    moveItem(
      document,
      _item(document, item),
      _item(document, target),
      below: below,
      selection: selection,
    ),
  ClearChecked(:final selection, :final list) => clearItems(
    document,
    checkedItems(
      document,
      list: switch (list) {
        null => null,
        final id => document.tree.blockOf(id)! as ListBlock,
      },
    ),
    selection,
  ),
  MoveToEnd(:final selection, :final items) => moveToEnd(
    document,
    switch (items) {
      null => checkedItems(document),
      final ids => [for (final id in ids) _item(document, id)],
    },
    selection,
  ),
};

ItemBlock _item(ShownDocument document, BlockId id) =>
    document.tree.blockOf(id)! as ItemBlock;
