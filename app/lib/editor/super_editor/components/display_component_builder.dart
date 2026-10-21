import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../display_nodes.dart';
import 'add_item_button.dart';
import 'display_actions.dart';
import 'done_heading.dart';
import 'drawn_table.dart';
import 'frames.dart';

/// Builds the components of [DisplayNode]s: "Done" headings, add buttons
/// and drawn tables. With no [actions] they are only shown.
class DisplayComponentBuilder implements ComponentBuilder {
  const DisplayComponentBuilder({this.actions});

  final DisplayActions? actions;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => node is DisplayNode ? DisplayViewModel(node) : null;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! DisplayViewModel) return null;
    final actions = this.actions;
    final node = componentViewModel.node;
    final context = componentContext.context;
    return BoxComponent(
      key: componentContext.componentKey,
      isVisuallySelectable: node is DrawnTableNode,
      child: switch (node) {
        DoneHeadingNode(:final entry) => DoneHeading(
          entry,
          onTap: actions == null ? null : () => actions.toggleDone(entry.list),
        ),
        AddItemNode(:final entry) => AddItemButton(
          onAdd: () => actions?.addItem(entry),
        ),
        DrawnTableNode(:final table, :final frames) => framed(
          frames,
          DrawnTable(
            table,
            onTap: actions == null ? null : () => actions.showRaw(table.id),
          ),
          row: (item, child) => Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(width: itemHandleWidth),
              MarkerView(item, style: DefaultTextStyle.of(context).style),
              Expanded(child: child),
            ],
          ),
        ),
      },
    );
  }
}

/// The view model of a [DisplayNode]'s component: the node itself, as
/// everything it shows is in it.
class DisplayViewModel extends SingleColumnLayoutComponentViewModel {
  DisplayViewModel(this.node, {super.padding = EdgeInsets.zero})
    : super(nodeId: node.id, createdAt: null);

  final DisplayNode node;

  @override
  DisplayViewModel copy() => DisplayViewModel(node, padding: padding)
    ..maxWidth = maxWidth
    ..opacity = opacity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      super == other && other is DisplayViewModel && other.node == node;

  @override
  int get hashCode => Object.hash(super.hashCode, node);
}
