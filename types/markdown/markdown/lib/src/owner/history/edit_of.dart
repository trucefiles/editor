import 'package:truce_core/truce_core.dart' show ShownStep, TextStep, Typing;

import '../../doc/origin.dart';
import '../../edit/commands/acted_on.dart';
import '../editor_contract.dart';
import 'markdown_step.dart';
import 'typing.dart';

/// The edit [input] made, from [before] read from [from] to [after] read
/// from [to], as an undo step, and the typing it was; in Visual edit,
/// shown at the rows its commands acted at ([acted]).
({MarkdownStep step, Typing? typing}) editOf(
  EditorInput input, {
  required EditorState before,
  required EditorState after,
  required Origin from,
  required Origin to,
  required ActedAt? acted,
}) => switch ((input, before.content, after.content)) {
  (final EditText input, MarkdownContent(), MarkdownContent()) => (
    step: TextChangeStep(TextStep(input.edit.change)),
    typing: textTypingOf(input),
  ),
  (_, final FormattedContent was, final FormattedContent now) => (
    step: TreeStep(
      ShownStep(
        TreeSide(was, from, at: acted?.before),
        TreeSide(now, to, at: acted?.after),
      ),
    ),
    typing: typingOf(input, before, after),
  ),
  _ => throw StateError('an edit changed the mode, or no text edit made it'),
};
