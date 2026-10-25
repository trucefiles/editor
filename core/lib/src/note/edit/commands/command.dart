/// The commands of Visual edit: every user action that changes a note.
/// Each is a pure function of the shown note; [run] runs one.
library;

import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
import '../shown/slot.dart';
import 'indent.dart';
import 'remove_frame.dart';
import 'split_block.dart';
import 'text_commands.dart';

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
});
