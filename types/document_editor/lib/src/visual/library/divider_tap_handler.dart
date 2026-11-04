import 'package:super_editor/super_editor.dart';

/// Hands a tap to [placeCaret], which puts the caret right after the
/// divider at the tapped position and tells whether there was one; a tap
/// elsewhere goes on as usual. A divider has no caret place of its own,
/// so the library alone would put the caret in the nearest text.
class DividerTapHandler extends ContentTapDelegate {
  DividerTapHandler(this.placeCaret);

  final bool Function(DocumentPosition position) placeCaret;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) => switch (details
      .documentLayout
      .getDocumentPositionNearestToOffset(details.layoutOffset)) {
    final position? when placeCaret(position) => TapHandlingInstruction.halt,
    _ => TapHandlingInstruction.continueHandling,
  };
}
