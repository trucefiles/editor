import 'package:flutter/material.dart';

import '../../document_metrics.dart';
import '../../ui/list_marker.dart';
import '../row_looks.dart';

/// [child] inside [frames], outermost first, spaced by [metrics]: a bar
/// beside it per quote, indented under the items it is in, as far as the
/// text of the item it is right in. If it starts that item, [row] puts
/// the item's row beside it. A line gap above and below it, and outside
/// items, unless it is one of a list's own rows ([ofList]: Add item, the
/// Done heading), a blank line's space below it too, so blocks stand
/// apart as in Read. Each space goes beside the bars of the quotes that
/// go on past it, so their bars run through it, and past the others.
Widget framed(
  List<Frame> frames,
  Widget child, {
  required DocumentMetrics metrics,
  required Widget Function(ItemFrame item, Widget child) row,
  bool ofList = false,
}) {
  final item = frames.whereType<ItemFrame>().lastOrNull;
  // Space stays outside an item's row, so its marker stays beside its
  // text.
  final rowDepth = item != null && item.starts
      ? frames.indexOf(item)
      : frames.length;
  int insideQuotes(bool Function(QuoteFrame quote) goOn) =>
      frames
          .take(rowDepth)
          .toList()
          .lastIndexWhere((frame) => frame is QuoteFrame && goOn(frame)) +
      1;
  final above = insideQuotes((quote) => !quote.starts);
  final below = insideQuotes((quote) => !quote.ends);
  final standsApart = item == null && !ofList;
  final gapBelow = metrics.lineGap + (standsApart ? metrics.blankLine : 0);
  return Iterable.generate(frames.length + 1, (i) => frames.length - i).fold(
    child,
    (child, depth) {
      final spaced = depth == above || depth == below
          ? Padding(
              padding: EdgeInsets.only(
                top: depth == above ? metrics.lineGap : 0,
                bottom: depth == below ? gapBelow : 0,
              ),
              child: child,
            )
          : child;
      return depth == 0
          ? spaced
          : _inFrame(frames[depth - 1], spaced, item, metrics, row);
    },
  );
}

/// [child], one of a list's own rows, inside the list's [frames] (only
/// quotes: a list with such rows is in no item); see [framed].
Widget framedListRow(
  List<Frame> frames,
  Widget child, {
  required DocumentMetrics metrics,
}) => framed(
  frames,
  child,
  metrics: metrics,
  row: (_, child) => child,
  ofList: true,
);

Widget _inFrame(
  Frame frame,
  Widget child,
  ItemFrame? item,
  DocumentMetrics metrics,
  Widget Function(ItemFrame item, Widget child) row,
) => switch (frame) {
  QuoteFrame() => _QuoteBar(child, indent: metrics.quoteIndent),
  ItemFrame() when frame != item => Padding(
    padding: EdgeInsets.only(left: metrics.levelIndent),
    child: child,
  ),
  ItemFrame(starts: true) => row(frame, child),
  ItemFrame() => Padding(
    padding: EdgeInsets.only(left: metrics.handleWidth + metrics.markerWidth),
    child: child,
  ),
};

/// The marker of [item] (see [ListMarker]) in [style]; its box checks
/// or unchecks by [onToggle].
class MarkerView extends StatelessWidget {
  const MarkerView(this.item, {required this.style, this.onToggle, super.key});

  final ItemFrame item;
  final TextStyle style;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) =>
      ListMarker(item.marker, style: style, onToggle: onToggle);
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
