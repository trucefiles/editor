import 'package:truce_core/truce_core.dart'
    show ShownStep, TextStep, Typing, textChange;

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
}) => switch ((before.content, after.content)) {
  (MarkdownContent(text: final was), MarkdownContent(:final text)) =>
    switch (textChange(was, text)) {
      final change => (
        step: TextChangeStep(TextStep(change)),
        typing: textTypingOf(input, change),
      ),
    },
  (final FormattedContent was, final FormattedContent now) => (
    step: TreeStep(
      ShownStep(
        TreeSide(was, from, at: acted?.before),
        TreeSide(now, to, at: acted?.after),
      ),
    ),
    typing: typingOf(input, before, after),
  ),
  _ => throw StateError('an edit changed the mode'),
};
