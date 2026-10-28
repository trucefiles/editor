import 'line.dart';

/// A text as the lines a line editor edits: each line keeps its id while
/// its text changes, so the editor can follow it. A change gives lines of
/// the same kind ([Self]).
abstract interface class EditableLines<Self extends EditableLines<Self>> {
  /// At least one line.
  List<Line> get lines;

  String get text;

  /// The index of line [id]; only for a line of these lines.
  int indexOf(LineId id);

  /// These lines with [lines], as the editor holds them, in place of
  /// those from [start] to [end]; a line that keeps its id keeps its
  /// line ending.
  Self withLines(int start, int end, List<({LineId? id, String text})> lines);

  /// These lines with [text] instead: the unchanged lines at its start
  /// and end keep their ids.
  Self withText(String text);
}
