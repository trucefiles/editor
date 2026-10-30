import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show NodeId;

import '../../document_metrics.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'frames.dart';
import 'item_row.dart';

/// Any row of Visual edit, [content] showing the block [leaf] (text, a
/// raw block open as text, or a block shown whole), inside its [frames]
/// (see [framed]). Every row that starts an item is the same: its
/// [ItemRow] beside it, the delete button shown while [active] (the
/// selection is in the row), and the whole row a [MovableItem]. [copy]
/// is what the drag copy shows of it; [style] the document's body text
/// style.
class FramedRow extends StatelessWidget {
  const FramedRow({
    required this.frames,
    required this.leaf,
    required this.content,
    required this.copy,
    required this.active,
    required this.style,
    required this.actions,
    super.key,
  });

  final List<Frame> frames;
  final NodeId leaf;
  final Widget content;
  final Widget copy;
  final bool active;
  final TextStyle style;
  final VisualActions actions;

  @override
  Widget build(BuildContext context) {
    final shown = framed(
      frames,
      content,
      metrics: DocumentMetrics.of(context),
      row: (item, content) => ItemRow(
        item: item,
        leaf: leaf,
        content: content,
        copy: copy,
        active: active,
        style: style,
        actions: actions,
      ),
    );
    return switch (frames.whereType<ItemFrame>().lastOrNull) {
      final item? when item.starts => MovableItem(
        item: item.item,
        leaf: leaf,
        actions: actions,
        child: shown,
      ),
      _ => shown,
    };
  }
}
