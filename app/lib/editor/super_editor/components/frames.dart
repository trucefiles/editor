import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// Indent of an item's text under the items it is in, per level.
const itemLevelIndent = 28.0;

/// Width before an item's marker, where its drag handle sits.
const itemHandleWidth = 24.0;

/// Width of an item's box, bullet or number.
const itemMarkerWidth = 36.0;

/// Indent of a quote's text, right of its bar.
const _quoteIndent = 12.0;

/// [child] inside [frames], outermost first: a bar beside it per quote,
/// indented under the items it is in, as far as the text of the item it
/// is right in. If it starts that item, [row] puts the item's row beside
/// it.
Widget framed(
  List<Frame> frames,
  Widget child, {
  required Widget Function(ItemFrame item, Widget child) row,
}) {
  final item = frames.whereType<ItemFrame>().lastOrNull;
  return frames.reversed.fold(
    child,
    (child, frame) => switch (frame) {
      QuoteFrame() => _QuoteBar(child),
      ItemFrame() when frame != item => Padding(
        padding: const EdgeInsets.only(left: itemLevelIndent),
        child: child,
      ),
      ItemFrame(showsMarker: true) => row(frame, child),
      ItemFrame() => Padding(
        padding: const EdgeInsets.only(left: itemHandleWidth + itemMarkerWidth),
        child: child,
      ),
    },
  );
}

/// Space between a marker and its item's text.
const _markerGap = 8.0;

/// The marker of [item]: its box, which [onToggle] checks or unchecks,
/// its bullet, or its number, in [style]. Every kind ends the same gap
/// before the text, as lists are drawn on the web, so numbers line up on
/// their dot; centered on the item's first line of text, also where it is
/// higher than the line.
class MarkerView extends StatelessWidget {
  const MarkerView(this.item, {required this.style, this.onToggle, super.key});

  final ItemFrame item;
  final TextStyle style;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => Container(
    width: itemMarkerWidth,
    height: _lineHeight(context),
    padding: const EdgeInsetsDirectional.only(end: _markerGap),
    child: OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      maxHeight: double.infinity,
      alignment: AlignmentDirectional.centerEnd,
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

/// [child] in a quote: a bar on its left, so it stands apart from the
/// text around it.
class _QuoteBar extends StatelessWidget {
  const _QuoteBar(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Padding(
        padding: const EdgeInsets.only(left: _quoteIndent),
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
