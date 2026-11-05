/// The commands of Visual edit: every user action that changes a
/// document. Each is a pure function of what shows; [run] runs one.
library;

import '../../doc/doc_nodes.dart';
import '../../doc/doc_tree.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import 'add_divider.dart';
import 'heading.dart';
import 'indent.dart';
import 'items.dart';
import 'line_after.dart';
import 'line_in_place.dart';
import 'links.dart';
import 'over_range.dart';
import 'paste.dart';
import 'raw_blocks.dart';
import 'remove_block.dart';
import 'remove_frame.dart';
import 'set_frame.dart';
import 'split_block.dart';
import 'styles.dart';
import 'text_commands.dart';

export 'heading.dart' show nextHeadingLevel;
export 'indent.dart' show canIndent, canOutdent;
export 'items.dart' show AddAt;
export 'set_frame.dart' show FrameKind;

/// One user action, with the places it acts on.
sealed class Command {
  const Command();
}

/// A command that is one change of the document.
sealed class EditCommand extends Command {
  const EditCommand();
}

/// Paste of [lines] over [selection] (see `plainLines`, `copiedLines`);
/// see `paste`.
final class Paste extends Command {
  const Paste(this.selection, this.lines);

  final Selection selection;
  final List<VisibleText> lines;
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

/// Types [text], literal, at [at] in [formatting] (the typing style).
final class InsertText extends EditCommand {
  const InsertText(this.at, this.text, this.formatting);

  final Place at;
  final String text;
  final Formatting formatting;
}

/// Replaces the text in [range], within one text place, by [text], as an
/// input method does (autocorrect, a suggestion, a composing word) and as
/// typing over a selection does (see `replaceText`).
final class ReplaceText extends EditCommand {
  const ReplaceText(this.range, this.text);

  final TextSelection range;
  final String text;
}

/// Removes what [selection] holds: its text, or the block selected whole
/// (the caret then goes up, as by Backspace).
final class DeleteRange extends EditCommand {
  const DeleteRange(this.selection);

  final Selection selection;
}

/// Backspace at [at], a text place's start: its text joins the text
/// place above.
final class JoinWithPrevious extends EditCommand {
  const JoinWithPrevious(this.at);

  final Place at;
}

/// Delete at [at], a text place's end: the text place below joins it.
final class JoinWithNext extends EditCommand {
  const JoinWithNext(this.at);

  final Place at;
}

/// Backspace at the start of [leaf], the first text of its innermost
/// item or quote: that frame goes (see `removeFrame`).
final class RemoveFrame extends EditCommand {
  const RemoveFrame(this.leaf);

  final NodeId leaf;
}

/// Tab (or a swipe) in the item at [selection]'s caret: it becomes a
/// subitem of the item above; the selection stays.
final class Indent extends EditCommand {
  const Indent(this.selection);

  final TextSelection selection;
}

/// Shift+Tab (or a swipe) in the item at [selection]'s caret: it goes one
/// level out; the selection stays.
final class Outdent extends EditCommand {
  const Outdent(this.selection);

  final TextSelection selection;
}

/// The heading button or shortcut at [at]: its text a heading of [level],
/// or a paragraph if `null`.
final class SetHeading extends EditCommand {
  const SetHeading(this.at, this.level);

  final Place at;
  final int? level;
}

/// A checked item's wait ended, or a box toggled at once: [item]'s box
/// toggled; no caret after it, as after the other commands on items as a
/// whole.
final class Toggle extends EditCommand {
  const Toggle(this.item);

  final NodeId item;
}

/// The row delete button on [item]: it goes with its subitems.
final class DeleteItem extends EditCommand {
  const DeleteItem(this.item);

  final NodeId item;
}

/// Backspace ([backward]) or Delete on [block], a divider selected
/// whole: it goes, as one selected character.
final class RemoveSelectedBlock extends EditCommand {
  const RemoveSelectedBlock(this.block, {required this.backward});

  final NodeId block;
  final bool backward;
}

/// Backspace or Delete at [caret], right next to [block], a divider: it
/// goes, as one character, and the caret stays where it was.
final class RemoveBlockNextTo extends EditCommand {
  const RemoveBlockNextTo(this.block, this.caret);

  final NodeId block;
  final Place caret;
}

/// Enter with the caret right after [block], a divider: an empty line
/// after it.
final class LineAfter extends EditCommand {
  const LineAfter(this.block);

  final NodeId block;
}

/// Enter on [block], selected whole: an empty line in its place.
final class LineInPlace extends EditCommand {
  const LineInPlace(this.block);

  final NodeId block;
}

/// The toolbar's Separator: a divider after the block [after] (the
/// caret's, or a selected divider), or after its item.
final class AddDivider extends EditCommand {
  const AddDivider(this.after);

  final NodeId after;
}

/// The Add item button of [list]: a new empty item, [at] its place.
final class AddItem extends EditCommand {
  const AddItem(this.list, {this.at = AddAt.last});

  final NodeId list;
  final AddAt at;
}

/// A drop: [item] with its subitems right before [target], or after it
/// if [below] (no caret after it, see [Toggle]).
final class MoveItem extends EditCommand {
  const MoveItem(this.item, this.target, {required this.below});

  final NodeId item;
  final NodeId target;
  final bool below;
}

/// "Clear checked items now": the checked items at the top level of
/// [list], or of every list if `null`, go with their subitems; a list
/// left empty keeps one empty open item (see [Toggle]: no caret after
/// it).
final class ClearChecked extends EditCommand {
  const ClearChecked({this.list});

  final NodeId? list;
}

/// "Move checked items to end now", or a checked item's wait ending:
/// [items] (by default every checked item at a list's top level) move to
/// the end of their lists (no caret after it, see [Toggle]).
final class MoveToEnd extends EditCommand {
  const MoveToEnd({this.items});

  final List<NodeId>? items;
}

/// A frame button or shortcut: [kind] set on what [selection] covers, or
/// taken off where all of it has it (see `setFrame`).
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

/// A raw block closed (the caret left it, or a command comes) with [raw]
/// typed in it (see `closeRaw`); [selection] stays where its text stays,
/// or, if `null`, what [raw] reads as is selected.
final class CloseRaw extends EditCommand {
  const CloseRaw(this.block, this.raw, this.selection);

  final NodeId block;
  final String raw;
  final Selection? selection;
}

/// What [view] shows after [command], with the selection after it.
Edited run(ViewRows view, Command command) => switch (command) {
  Paste(:final selection, :final lines) => paste(view, selection, lines),
  LineBreak(:final range) => overRange(view, range, lineBreak),
  SplitBlock(:final range) => overRange(view, range, splitBlock),
  final EditCommand command => settled(_change(view, command)),
};

Change _change(ViewRows view, EditCommand command) {
  T node<T extends DocBlock>(NodeId id) => view.doc.nodeOf(id)! as T;
  return switch (command) {
    InsertText(:final at, :final text, :final formatting) => insertText(
      view,
      at,
      text,
      formatting,
    ),
    ReplaceText(:final range, :final text) => replaceText(view, range, text),
    DeleteRange(selection: final TextSelection range) => deleteRange(
      view,
      range,
    ),
    DeleteRange(selection: BlockSelection(:final block)) => removeSelectedBlock(
      view,
      block,
      backward: true,
    ),
    DeleteRange(selection: final BlockCaret caret) => (
      doc: view.doc,
      caret: CaretAt(caret),
    ),
    JoinWithPrevious(:final at) => joinWithPrevious(view, at),
    JoinWithNext(:final at) => joinWithNext(view, at),
    RemoveFrame(:final leaf) => removeFrame(view, leaf),
    Indent(:final selection) => indent(view, selection),
    Outdent(:final selection) => outdent(view, selection),
    SetHeading(:final at, :final level) => setHeading(view, at, level),
    SetFrame(:final selection, :final kind) => setFrame(view, selection, kind),
    SetLink(:final range, :final text, :final url) => setLink(
      view,
      range,
      text,
      url,
    ),
    RemoveLink(:final at) => removeLink(view, at),
    ToggleStyle(:final selection, :final format) => toggleStyle(
      view,
      selection,
      format,
    ),
    Toggle(:final item) => toggle(view, node(item)),
    DeleteItem(:final item) => deleteItem(view, node(item)),
    RemoveSelectedBlock(:final block, :final backward) => removeSelectedBlock(
      view,
      block,
      backward: backward,
    ),
    RemoveBlockNextTo(:final block, :final caret) => removeBlockNextTo(
      view,
      block,
      caret,
    ),
    AddItem(:final list, :final at) => addItem(view, node(list), at: at),
    AddDivider(:final after) => addDivider(view, after),
    LineInPlace(:final block) => lineInPlace(view, block),
    LineAfter(:final block) => lineAfter(view, block),
    MoveItem(:final item, :final target, :final below) => moveItem(
      view,
      node(item),
      node(target),
      below: below,
    ),
    final ClearChecked command => clearItems(
      view,
      clearedItems(view.doc, command),
    ),
    final MoveToEnd command => moveToEnd(view, movedItems(view.doc, command)),
    CloseRaw(:final block, :final raw, :final selection) => closeRaw(
      view,
      block,
      raw,
      selection,
    ),
  };
}

/// The items [command] clears in [doc]: the checked ones of its list, or
/// of every list.
List<ItemNode> clearedItems(DocTree doc, ClearChecked command) => checkedItems(
  doc,
  list: switch (command.list) {
    null => null,
    final id => doc.nodeOf(id)! as ListNode,
  },
);

/// The items [command] moves to the end of their lists in [doc]: the ones
/// it names, else every checked one.
List<ItemNode> movedItems(DocTree doc, MoveToEnd command) =>
    switch (command.items) {
      null => checkedItems(doc),
      final ids => [for (final id in ids) doc.nodeOf(id)! as ItemNode],
    };
