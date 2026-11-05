import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show Frame, ItemFrame;

import '../../document_metrics.dart';
import '../visual_actions.dart';
import 'frames.dart';
import 'item_row.dart';

/// Any row of Visual edit, [content] showing a block (text, a raw block
/// open as text, or a block shown whole), inside its [frames]
/// (see [framed]). Every row that starts an item is the same: its
/// [ItemRow] beside it, the delete button shown while [active] (the
/// selection is in the row), and the whole row a [MovableItem]. [copy]
/// is what the drag copy shows of it; [style] the document's body text
/// style. The item's row keeps one key while the row shows, so it stays
/// the same row when the item changes level.
class FramedRow extends StatefulWidget {
  const FramedRow({
    required this.frames,
    required this.content,
    required this.copy,
    required this.active,
    required this.style,
    required this.actions,
    super.key,
  });

  final List<Frame> frames;
  final Widget content;
  final Widget copy;
  final bool active;
  final TextStyle style;
  final VisualActions actions;

  @override
  State<FramedRow> createState() => _FramedRowState();
}

class _FramedRowState extends State<FramedRow> {
  final _row = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final shown = framed(
      widget.frames,
      widget.content,
      metrics: DocumentMetrics.of(context),
      row: (item, content) => ItemRow(
        row: _row,
        item: item,
        content: content,
        copy: widget.copy,
        active: widget.active,
        style: widget.style,
        actions: widget.actions,
      ),
    );
    return switch (widget.frames.whereType<ItemFrame>().lastOrNull) {
      final item? when item.starts => MovableItem(
        item: item.item,
        row: _row,
        actions: widget.actions,
        child: shown,
      ),
      _ => shown,
    };
  }
}
