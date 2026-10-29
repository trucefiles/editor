import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';
import 'package:truce_markdown/truce_markdown.dart' as md;

import '../../document_metrics.dart';
import '../../document_text_styles.dart';
import '../library/library_nodes.dart';
import '../row_looks.dart';
import '../visual_actions.dart';
import 'add_item_button.dart';
import 'done_heading.dart';
import 'drawn_table.dart';
import 'frames.dart';

/// Builds the components of rows shown whole: dividers, drawn tables and
/// raw blocks inside their frames (a tap on a table or raw block opens
/// its raw text), Done headings and Add item buttons; each does what it
/// offers by [actions].
class BlockBuilder implements ComponentBuilder {
  const BlockBuilder(this.actions);

  final VisualActions actions;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => node is LookBlockNode ? BlockViewModel(node.id, node.look) : null;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! BlockViewModel) return null;
    final look = componentViewModel.look;
    final context = componentContext.context;
    final metrics = DocumentMetrics.of(context);
    return BoxComponent(
      key: componentContext.componentKey,
      isVisuallySelectable: look is BlockLook,
      child: switch (look) {
        BlockLook(:final leaf, :final frames) => framed(
          frames,
          _block(leaf, context),
          metrics: metrics,
          row: (item, child) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: metrics.handleWidth),
              MarkerView(
                item,
                style: DocumentTextStyles.body(Theme.of(context)),
                onToggle: () => actions.toggle(item.item),
              ),
              Expanded(child: child),
            ],
          ),
        ),
        DoneHeadingLook(:final list, :final count, :final collapsed) =>
          DoneHeading(
            count: count,
            collapsed: collapsed,
            onTap: () => actions.setCollapsed(list, collapsed: !collapsed),
          ),
        AddItemLook(:final list, :final first) => AddItemButton(
          indent: metrics.handleWidth,
          onAdd: () => actions.addItem(list, first: first),
        ),
        TextLook() || RawTextLook() => throw StateError('a row with text'),
      },
    );
  }

  /// [leaf], a block without text, as it shows.
  Widget _block(md.DocLeaf leaf, BuildContext context) => switch (leaf) {
    md.TableNode() => DrawnTable(leaf, onTap: () => actions.openRaw(leaf.id)),
    md.RawNode(:final raw) => GestureDetector(
      onTap: () => actions.openRaw(leaf.id),
      child: Text(
        raw,
        style:
            DocumentTextStyles.monospace(
              DocumentTextStyles.body(Theme.of(context)),
            ).copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant
                  .withValues(alpha: 0.6),
            ),
      ),
    ),
    _ => const Divider(),
  };
}

/// The view model of a row shown whole: its [look], which says all it
/// shows.
class BlockViewModel extends SingleColumnLayoutComponentViewModel {
  BlockViewModel(String nodeId, this.look, {super.padding = EdgeInsets.zero})
    : super(nodeId: nodeId, createdAt: null);

  final RowLook look;

  @override
  BlockViewModel copy() => BlockViewModel(nodeId, look, padding: padding)
    ..maxWidth = maxWidth
    ..opacity = opacity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is BlockViewModel && other.look == look;

  @override
  int get hashCode => Object.hash(super.hashCode, look);
}
