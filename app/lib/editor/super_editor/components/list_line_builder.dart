import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

import 'line_actions.dart';
import 'list_line_component.dart';

/// Builds a [ListLineComponent] for each task and list item. With an
/// [editor], a task's box toggles it there; with [actions], each row
/// offers them.
class ListLineBuilder implements ComponentBuilder {
  const ListLineBuilder({this.editor, this.actions});

  final Editor? editor;
  final LineActions? actions;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) => switch (node) {
    TaskNode() => _taskViewModel(node),
    ListItemNode() => const ListItemComponentBuilder().createViewModel(
      document,
      node,
    ),
    _ => null,
  };

  TaskComponentViewModel _taskViewModel(TaskNode node) {
    final editor = this.editor;
    return TaskComponentViewModel(
      nodeId: node.id,
      padding: EdgeInsets.zero,
      indent: node.indent,
      isComplete: node.isComplete,
      setComplete: editor == null
          ? null
          : (checked) => editor.execute([
              ChangeTaskCompletionRequest(nodeId: node.id, isComplete: checked),
            ]),
      text: node.text,
      textDirection: getParagraphDirection(node.text.toPlainText()),
      textStyleBuilder: noStyleBuilder,
      selectionColor: const Color(0x00000000),
    );
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) => switch (componentViewModel) {
    TaskComponentViewModel(
      :final indent,
      :final isComplete,
      :final setComplete,
    ) =>
      _line(
        componentContext,
        componentViewModel,
        indent: indent,
        struckThrough: isComplete,
        marker: Checkbox(
          value: isComplete,
          onChanged: setComplete == null
              ? null
              : (checked) => setComplete(checked!),
        ),
      ),
    UnorderedListItemComponentViewModel(:final indent) => _line(
      componentContext,
      componentViewModel,
      indent: indent,
      marker: Text('•', style: componentViewModel.textStyleBuilder(const {})),
    ),
    OrderedListItemComponentViewModel(:final indent, :final ordinalValue) =>
      _line(
        componentContext,
        componentViewModel,
        indent: indent,
        marker: Text(
          '${ordinalValue ?? 1}.',
          style: componentViewModel.textStyleBuilder(const {}),
        ),
      ),
    _ => null,
  };

  Widget _line(
    SingleColumnDocumentComponentContext componentContext,
    TextComponentViewModel viewModel, {
    required int indent,
    required Widget marker,
    bool struckThrough = false,
  }) => ListLineComponent(
    key: componentContext.componentKey,
    viewModel: viewModel,
    indent: indent,
    marker: marker,
    struckThrough: struckThrough,
    actions: actions,
  );
}
