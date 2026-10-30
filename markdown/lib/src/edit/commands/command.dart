/// The commands of Visual edit: every user action that changes a
/// document. Each is a pure function of what shows; [run] runs one.
library;

import '../../doc/doc_nodes.dart';
import '../../view/rows.dart';
import '../../visible/formatting.dart';
import '../../visible/visible_text.dart';
import '../change.dart';
import '../selection.dart';
import 'add_divider.dart';
import 'heading.dart';
import 'indent.dart';
import 'items.dart';
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

/// Paste of [lines] over [range] (see `plainLines`, `copiedLines`); see
/// `paste`.
final class Paste extends Command {
  const Paste(this.range, this.lines);

  final TextSelection range;
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

/// Removes the text in [range].
final class DeleteRange extends EditCommand {
  const DeleteRange(this.range);

  final TextSelection range;
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

/// Tab in the item at [selection]'s caret: it becomes a subitem of the
/// item above. The selection is [after] then (e.g. the user's, kept while
/// a swipe indents another row), else [selection].
final class Indent extends EditCommand {
  const Indent(this.selection, {this.after});

  final TextSelection selection;
  final Selection? after;
}

/// Shift+Tab in the item at [selection]'s caret: it goes one level out.
/// The selection is [after] then, else [selection] (see [Indent]).
final class Outdent extends EditCommand {
  const Outdent(this.selection, {this.after});

  final TextSelection selection;
  final Selection? after;
}

/// The heading button or shortcut at [at]: its text a heading of [level],
/// or a paragraph if `null`.
final class SetHeading extends EditCommand {
  const SetHeading(this.at, this.level);

  final Place at;
  final int? level;
}

/// A checked item's wait ended, or a box toggled at once: [item]'s box
/// toggled; [selection] stays.
final class Toggle extends EditCommand {
  const Toggle(this.item, this.selection);

  final NodeId item;
  final Selection selection;
}

/// The row delete button on [item]: it goes with its subitems.
final class DeleteItem extends EditCommand {
  const DeleteItem(this.item);

  final NodeId item;
}

/// Backspace ([backward]) or Delete on [block], a selected divider: it
/// goes.
final class RemoveBlock extends EditCommand {
  const RemoveBlock(this.block, {required this.backward});

  final NodeId block;
  final bool backward;
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
/// if [below]; [selection] stays.
final class MoveItem extends EditCommand {
  const MoveItem(
    this.item,
    this.target, {
    required this.below,
    required this.selection,
  });

  final NodeId item;
  final NodeId target;
  final bool below;
  final Selection selection;
}

/// "Clear checked items now": the checked items at the top level of
/// [list], or of every list if `null`, go with their subitems.
final class ClearChecked extends EditCommand {
  const ClearChecked(this.selection, {this.list});

  final Selection selection;
  final NodeId? list;
}

/// "Move checked items to end now", or a checked item's wait ending:
/// [items] (by default every checked item at a list's top level) move to
/// the end of their lists; [selection] stays.
final class MoveToEnd extends EditCommand {
  const MoveToEnd(this.selection, {this.items});

  final Selection selection;
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
  Paste(:final range, :final lines) => paste(view, range, lines),
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
    DeleteRange(:final range) => deleteRange(view, range),
    JoinWithPrevious(:final at) => joinWithPrevious(view, at),
    JoinWithNext(:final at) => joinWithNext(view, at),
    RemoveFrame(:final leaf) => removeFrame(view, leaf),
    Indent(:final selection, :final after) => _then(
      indent(view, selection),
      after,
    ),
    Outdent(:final selection, :final after) => _then(
      outdent(view, selection),
      after,
    ),
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
    Toggle(:final item, :final selection) => toggle(
      view,
      node(item),
      selection,
    ),
    DeleteItem(:final item) => deleteItem(view, node(item)),
    RemoveBlock(:final block, :final backward) => removeBlock(
      view,
      block,
      backward: backward,
    ),
    AddItem(:final list, :final at) => addItem(view, node(list), at: at),
    AddDivider(:final after) => addDivider(view, after),
    MoveItem(:final item, :final target, :final below, :final selection) =>
      moveItem(
        view,
        node(item),
        node(target),
        below: below,
        selection: selection,
      ),
    ClearChecked(:final selection, :final list) => clearItems(
      view,
      checkedItems(
        view.doc,
        list: switch (list) {
          null => null,
          final id => node(id),
        },
      ),
      selection,
    ),
    MoveToEnd(:final selection, :final items) => moveToEnd(
      view,
      switch (items) {
        null => checkedItems(view.doc),
        final ids => [for (final id in ids) node<ItemNode>(id)],
      },
      selection,
    ),
    CloseRaw(:final block, :final raw, :final selection) => closeRaw(
      view,
      block,
      raw,
      selection,
    ),
  };
}

/// [change] with the selection [after], if given.
Change _then(Change change, Selection? after) =>
    after == null ? change : (doc: change.doc, selection: after);
