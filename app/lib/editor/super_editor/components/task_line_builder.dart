import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import 'line_actions.dart';
import 'task_line_component.dart';

/// Builds a [TaskLineComponent] for each task. With an [editor], its box
/// toggles the task there; with [actions], its row offers them.
class TaskLineBuilder implements ComponentBuilder {
  const TaskLineBuilder({this.editor, this.actions});

  final Editor? editor;
  final LineActions? actions;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(
    Document document,
    DocumentNode node,
  ) {
    if (node is! TaskNode) return null;
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
  ) => componentViewModel is TaskComponentViewModel
      ? TaskLineComponent(
          key: componentContext.componentKey,
          viewModel: componentViewModel,
          actions: actions,
        )
      : null;
}
