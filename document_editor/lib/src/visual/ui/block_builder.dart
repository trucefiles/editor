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
import 'item_row.dart';

/// Builds the components of rows shown whole: dividers, drawn tables and
/// raw blocks inside their frames (a tap on a table or raw block opens
/// its raw text; a divider selects whole and shows it), Done headings
/// and Add item buttons; each does what it offers by [actions]. One that
/// starts an item has the item's row, as a text does.
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
        BlockLook() => _shownWhole(look, componentViewModel, context),
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

  /// [look]'s block inside its frames, beside its item's row where it
  /// starts one.
  Widget _shownWhole(
    BlockLook look,
    BlockViewModel viewModel,
    BuildContext context,
  ) {
    final BlockLook(:leaf, :frames) = look;
    final selection =
        viewModel.selection?.nodeSelection as UpstreamDownstreamNodeSelection?;
    final selected = selection != null && !selection.isCollapsed;
    final block = switch (leaf) {
      // Takes no hits: a tap on it goes to the editor, which selects it.
      md.DividerNode() => IgnorePointer(
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: selected ? viewModel.selectionColor : Colors.transparent,
          ),
          child: _block(leaf, context),
        ),
      ),
      _ => _block(leaf, context),
    };
    final shown = framed(
      frames,
      block,
      metrics: DocumentMetrics.of(context),
      row: (item, child) => ItemRow(
        item: item,
        leaf: leaf.id,
        content: child,
        copy: _block(leaf, context),
        active: selected,
        style: DocumentTextStyles.body(Theme.of(context)),
        actions: actions,
      ),
    );
    return switch (frames.whereType<ItemFrame>().lastOrNull) {
      final item? when item.starts => MovableItem(
        item: item.item,
        leaf: leaf.id,
        actions: actions,
        child: shown,
      ),
      _ => shown,
    };
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
/// shows, and the selection on it.
class BlockViewModel extends SingleColumnLayoutComponentViewModel
    with SelectionAwareViewModelMixin {
  BlockViewModel(String nodeId, this.look, {super.padding = EdgeInsets.zero})
    : super(nodeId: nodeId, createdAt: null);

  final RowLook look;

  @override
  BlockViewModel copy() => BlockViewModel(nodeId, look, padding: padding)
    ..maxWidth = maxWidth
    ..opacity = opacity
    ..selection = selection
    ..selectionColor = selectionColor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is BlockViewModel && other.look == look;

  @override
  int get hashCode => Object.hash(super.hashCode, look);
}
