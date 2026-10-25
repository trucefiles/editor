/// Whether runs of `*`, `_` and `~` can open or close emphasis and
/// strikethrough, as CommonMark and GitHub Flavored Markdown define it.
/// The one owner of this rule, for reading and writing.
library;

import 'characters.dart';

/// Whether a run of [count] [char]s between [before] and [after] can
/// open and close a span: `(canOpen, canClose)`. [before] and [after]
/// are the characters around the run; `\n` at a text's start or end.
(bool, bool) delimiterRunFlanks(
  String char,
  int count, {
  required String before,
  required String after,
}) {
  final afterSpace = isUnicodeWhitespace(after);
  final afterPunctuation = isUnicodePunctuation(after);
  final beforeSpace = isUnicodeWhitespace(before);
  final beforePunctuation = isUnicodePunctuation(before);
  final leftFlanking =
      !afterSpace && (!afterPunctuation || beforeSpace || beforePunctuation);
  final rightFlanking =
      !beforeSpace && (!beforePunctuation || afterSpace || afterPunctuation);
  return switch (char) {
    '_' => (
      leftFlanking && (!rightFlanking || beforePunctuation),
      rightFlanking && (!leftFlanking || afterPunctuation),
    ),
    '~' when count > 2 => (false, false),
    _ => (leftFlanking, rightFlanking),
  };
}
