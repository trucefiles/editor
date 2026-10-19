import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import '../display_nodes.dart';
import 'add_item_buttons.dart';
import 'display_actions.dart';
import 'done_heading.dart';
import 'drawn_image.dart';
import 'drawn_table.dart';

/// Builds the components of [DisplayNode]s: "Done" headings, add buttons
/// and drawn tables and images. With no [actions] they are only shown.
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
    return BoxComponent(
      key: componentContext.componentKey,
      isVisuallySelectable: node is DrawnTableNode || node is DrawnImageNode,
      child: switch (node) {
        DoneHeadingNode(:final entry) => DoneHeading(
          entry,
          onTap: actions == null ? null : () => actions.toggleDone(entry.list),
        ),
        AddItemNode(:final entry) => AddItemButtons(
          onAdd: (kind) => actions?.addItem(entry, kind),
        ),
        DrawnTableNode(:final rows, :final lines) => DrawnTable(
          rows,
          onTap: actions == null ? null : () => actions.showRaw(lines.first.id),
        ),
        DrawnImageNode(:final entry) => DrawnImage(
          entry,
          onTap: actions == null ? null : () => actions.showRaw(entry.id),
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
