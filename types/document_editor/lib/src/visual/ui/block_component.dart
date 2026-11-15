import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// The component of a row shown whole (a divider, a table, a raw block):
/// a box measured on the block itself, not on its row's handle or delete
/// button. So the caret right after it (for the library a caret at the
/// box's end) stands at the block's right end, before the delete button,
/// one text line ([lineHeight]) high, centered on the block, as a caret
/// after a character does.
class BlockComponent extends StatefulWidget {
  const BlockComponent({
    required this.lineHeight,
    required this.row,
    super.key,
  });

  final double lineHeight;

  /// The row, given the box its block shows in.
  final Widget Function(Widget Function(Widget block) box) row;

  @override
  State<BlockComponent> createState() => _BlockComponentState();
}

class _BlockComponentState extends State<BlockComponent>
    with ProxyDocumentComponent<BlockComponent> {
  final _box = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => _box;

  @override
  Rect getRectForPosition(NodePosition nodePosition) =>
      _lineHigh(super.getRectForPosition(nodePosition));

  @override
  Rect getEdgeForPosition(NodePosition nodePosition) =>
      _lineHigh(super.getEdgeForPosition(nodePosition));

  @override
  CaretGeometry getCaretForPosition(NodePosition nodePosition) {
    final edge = getEdgeForPosition(nodePosition);
    return CaretGeometry(x: edge.left, top: edge.top, bottom: edge.bottom);
  }

  /// [rect] as high as a line of text, centered where it was.
  Rect _lineHigh(Rect rect) => Rect.fromCenter(
    center: rect.center,
    width: rect.width,
    height: widget.lineHeight,
  );

  @override
  Widget build(BuildContext context) =>
      widget.row((block) => BoxComponent(key: _box, child: block));
}
