import 'package:super_editor/super_editor.dart';

/// Hands a tap to [select], which selects the divider at the tapped
/// position whole and tells whether there was one; a tap elsewhere goes
/// on as usual. A divider has no caret place of its own, so the library
/// alone would put the caret in the nearest text.
class DividerTapHandler extends ContentTapDelegate {
  DividerTapHandler(this.select);

  final bool Function(DocumentPosition position) select;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) => switch (details
      .documentLayout
      .getDocumentPositionNearestToOffset(details.layoutOffset)) {
    final position? when select(position) => TapHandlingInstruction.halt,
    _ => TapHandlingInstruction.continueHandling,
  };
}
