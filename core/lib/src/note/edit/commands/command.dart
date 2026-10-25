/// The commands of Visual edit: every user action that changes a note.
/// Each is a pure function of the shown note; [run] runs one.
library;

import '../../visible/formatting.dart';
import '../commit.dart';
import '../shown/selection.dart';
import '../shown/shown_note.dart';
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
});
