import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../note_metrics.dart';

/// [child] inside [frames], outermost first, spaced by [metrics]: a bar
/// beside it per quote, indented under the items it is in, as far as the
/// text of the item it is right in. If it starts that item, [row] puts
/// the item's row beside it.
Widget framed(
  List<Frame> frames,
  Widget child, {
  required NoteMetrics metrics,
  required Widget Function(ItemFrame item, Widget child) row,
}) {
  final item = frames.whereType<ItemFrame>().lastOrNull;
  return frames.reversed.fold(
    child,
    (child, frame) => switch (frame) {
      QuoteFrame() => _QuoteBar(child, indent: metrics.quoteIndent),
      ItemFrame() when frame != item => Padding(
        padding: EdgeInsets.only(left: metrics.levelIndent),
        child: child,
      ),
      ItemFrame(showsMarker: true) => row(frame, child),
      ItemFrame() => Padding(
        padding: EdgeInsets.only(
          left: metrics.handleWidth + metrics.markerWidth,
        ),
        child: child,
      ),
    },
  );
}

/// The marker of [item]: its box, which [onToggle] checks or unchecks,
/// its bullet, or its number, in [style]. Every kind ends the same gap
/// before the text (a box where it is drawn), as lists are drawn on the
/// web, so numbers line up on their dot; centered on the item's first
/// line of text, also where it is higher than the line. Sized by the
/// [NoteMetrics] of its context.
class MarkerView extends StatelessWidget {
  const MarkerView(this.item, {required this.style, this.onToggle, super.key});

  final ItemFrame item;
  final TextStyle style;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final metrics = NoteMetrics.of(context);
    return SizedBox(
      width: metrics.markerWidth,
      height: _lineHeight(context),
      child: CustomSingleChildLayout(
        delegate: _MarkerLayout(
          Directionality.of(context),
          gap: metrics.markerGap,
          // A checkbox draws its box in the middle of its tap area.
          drawnWidth: item.kind == ListKind.checkbox ? Checkbox.width : null,
        ),
        child: switch (item.kind) {
          ListKind.checkbox => Checkbox(
            value: item.checked,
            // As high as a line of text, so lists stay compact.
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: switch (onToggle) {
              final toggle? => (_) => toggle(),
              null => null,
            },
          ),
          ListKind.bullet => Text('•', style: style),
          ListKind.numbered => Text('${item.number ?? 1}.', style: style),
        },
      ),
    );
  }

  /// The height of a line of text in [style], as the text beside lays it
  /// out.
  double _lineHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }
}

/// A marker as large as it wants, placed so that what it draws, the
/// [drawnWidth] in its middle (all of it if `null`), ends [gap] before
/// the end of its slot; centered in the slot's height.
class _MarkerLayout extends SingleChildLayoutDelegate {
  const _MarkerLayout(this.direction, {required this.gap, this.drawnWidth});

  final TextDirection direction;
  final double gap;
  final double? drawnWidth;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final margin = (childSize.width - (drawnWidth ?? childSize.width)) / 2;
    final fromEnd = gap - margin;
    return Offset(switch (direction) {
      TextDirection.ltr => size.width - fromEnd - childSize.width,
      TextDirection.rtl => fromEnd,
    }, (size.height - childSize.height) / 2);
  }

  @override
  bool shouldRelayout(_MarkerLayout oldDelegate) =>
      oldDelegate.direction != direction ||
      oldDelegate.gap != gap ||
      oldDelegate.drawnWidth != drawnWidth;
}

/// [child] in a quote: a bar on its left, so it stands apart from the
/// text around it; the text [indent] right of it.
class _QuoteBar extends StatelessWidget {
  const _QuoteBar(this.child, {required this.indent});

  final Widget child;
  final double indent;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: EdgeInsets.only(left: indent),
        child: child,
      ),
      // Takes no hits: anything hit over the text keeps super_editor from
      // placing the caret there.
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: 3,
        child: IgnorePointer(
          child: ColoredBox(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    ],
  );
}
