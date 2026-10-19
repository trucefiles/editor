import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import 'visual_lines.dart';

/// Wraps the component of a text node that may show formatted (see
/// [VisualLines]): turns the positions its child reports into positions
/// in the node's text, so taps and caret moves land on the right
/// character. While the node shows its own text, it passes everything on.
///
/// Only positions coming out are mapped: the caret and selection are
/// never drawn on a formatted line.
class MappedTextComponent extends StatefulWidget {
  const MappedTextComponent({
    required this.nodeId,
    required this.lines,
    required this.child,
    super.key,
  });

  final String nodeId;
  final VisualLines lines;

  /// Builds the child component with the given key.
  final Widget Function(GlobalKey key) child;

  @override
  State<MappedTextComponent> createState() => _MappedTextComponentState();
}

class _MappedTextComponentState extends State<MappedTextComponent>
    with ProxyDocumentComponent<MappedTextComponent>, ProxyTextComposable {
  final _childKey = GlobalKey();

  @override
  GlobalKey get childDocumentComponentKey => _childKey;

  @override
  TextComposable get childTextComposable =>
      _childKey.currentState! as TextComposable;

  NodePosition _out(NodePosition position) =>
      switch ((widget.lines.of(widget.nodeId), position)) {
        (final line?, TextNodePosition(:final offset, :final affinity)) =>
          TextNodePosition(offset: line.toSource(offset), affinity: affinity),
        _ => position,
      };

  @override
  NodePosition? getPositionAtOffset(Offset localOffset) =>
      switch (super.getPositionAtOffset(localOffset)) {
        final position? => _out(position),
        null => null,
      };

  @override
  NodePosition getBeginningPosition() => _out(super.getBeginningPosition());

  @override
  NodePosition getBeginningPositionNearX(double x) =>
      _out(super.getBeginningPositionNearX(x));

  @override
  NodePosition getEndPosition() => _out(super.getEndPosition());

  @override
  NodePosition getEndPositionNearX(double x) =>
      _out(super.getEndPositionNearX(x));

  @override
  NodeSelection? getSelectionInRange(Offset base, Offset extent) =>
      switch (super.getSelectionInRange(base, extent)) {
        TextNodeSelection(:final baseOffset, :final extentOffset) =>
          TextNodeSelection(
            baseOffset: _offsetOut(baseOffset),
            extentOffset: _offsetOut(extentOffset),
          ),
        final other => other,
      };

  @override
  NodeSelection getSelectionOfEverything() => TextNodeSelection(
    baseOffset: 0,
    extentOffset: _offsetOut(childTextComposable.getAllText().length),
  );

  int _offsetOut(int offset) =>
      widget.lines.of(widget.nodeId)?.toSource(offset) ?? offset;

  @override
  Widget build(BuildContext context) => widget.child(_childKey);
}
