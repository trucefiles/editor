import 'package:truce_core/truce_core.dart';

/// One line of a version compared with another: its text, and whether
/// only this version has it.
typedef ComparedLine = ({String text, bool onlyHere});

/// The lines of [shown], each marked if [other] lacks it, as a line diff
/// matches them. A changed or moved line counts as only here.
List<ComparedLine> compareLines(List<String> shown, List<String> other) => [
  for (final (line, before) in oldLinesOf(other, shown).indexed)
    (text: shown[line], onlyHere: before == null),
];
