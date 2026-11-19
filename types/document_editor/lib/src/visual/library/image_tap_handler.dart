import 'package:super_editor/super_editor.dart';

import 'visual_adapter.dart';

/// Hands a tap on an image itself to [onImage]; a tap beside it, on its
/// line, goes on as usual and places the caret there. [imageAt] tells the
/// image at a position, if any.
class ImageTapHandler extends ContentTapDelegate {
  ImageTapHandler({required this.imageAt, required this.onImage});

  final ShownImage? Function(DocumentPosition position) imageAt;
  final void Function(ShownImage image) onImage;

  @override
  TapHandlingInstruction onTap(DocumentTapDetails details) {
    final layout = details.documentLayout;
    final position = layout.getDocumentPositionNearestToOffset(
      details.layoutOffset,
    );
    final image = position == null ? null : imageAt(position);
    if (image == null) return TapHandlingInstruction.continueHandling;
    final box = layout.getRectForSelection(image.start, image.end);
    if (box == null || !box.contains(details.layoutOffset)) {
      return TapHandlingInstruction.continueHandling;
    }
    onImage(image);
    return TapHandlingInstruction.halt;
  }
}
