import 'package:super_editor/super_editor.dart';

/// Styles a line editor's lines and finds the links in them; made for one
/// editor and disposed with it.
abstract interface class LineHighlighter {
  /// Styles the lines, as one of the library's style phases.
  SingleColumnLayoutStylePhase get phase;

  /// Where the link at [position] leads; `null` if there is none.
  String? linkAt(DocumentPosition position);

  void dispose();
}
