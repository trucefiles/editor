import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truce_core/truce_core.dart';

import 'swipe_to_indent.dart';

/// Indent per checklist level.
const _levelIndent = 28.0;

/// One checkbox item: checkbox, inline-editable text and a menu. Swipe
/// right or left to indent or outdent.
class ChecklistItemRow extends StatefulWidget {
  const ChecklistItemRow({
    required this.line,
    required this.depth,
    required this.onToggle,
    required this.onTextChanged,
    required this.onSubmitted,
    required this.onAction,
    required this.focusNode,
    required this.onFocusStep,
    this.dragHandle,
    super.key,
  });

  final ChecklistLine line;
  final int depth;
  final VoidCallback onToggle;
  final ValueChanged<String> onTextChanged;

  /// Enter: the next item is created.
  final VoidCallback onSubmitted;
  final ValueChanged<ItemAction> onAction;

  /// Wraps the drag icon so it starts a reorder; `null` if not draggable.
  final Widget Function(Widget icon)? dragHandle;

  /// Focus of the text field; owned by the list, which moves it between
  /// rows.
  final FocusNode focusNode;

  /// Arrow up (−1) or down (+1): the cursor should go to the next row.
  final ValueChanged<int> onFocusStep;

  @override
  State<ChecklistItemRow> createState() => _ChecklistItemRowState();
}

enum ItemAction { indent, outdent, delete }

class _ChecklistItemRowState extends State<ChecklistItemRow> {
  late final _text = TextEditingController(text: widget.line.text);

  @override
  void didUpdateWidget(ChecklistItemRow old) {
    super.didUpdateWidget(old);
    // Text changed elsewhere (another device, undo): show it unless the
    // user is typing here.
    if (!widget.focusNode.hasFocus && _text.text != widget.line.text) {
      _text.text = widget.line.text;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SwipeToIndent(
      onIndent: () => widget.onAction(ItemAction.indent),
      onOutdent: () => widget.onAction(ItemAction.outdent),
      child: _row(context),
    );
  }

  Widget _row(BuildContext context) {
    final checked = widget.line.isChecked;
    final textStyle = checked
        ? TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Theme.of(context).disabledColor,
          )
        : null;
    final handle = widget.dragHandle;
    return Padding(
      padding: EdgeInsets.only(left: widget.depth * _levelIndent),
      child: Row(
        children: [
          if (handle != null)
            SwipeToIndent.keepMouseDrags(
              handle(const Icon(Icons.drag_indicator)),
            )
          else
            const SizedBox(width: 24),
          Checkbox(value: checked, onChanged: (_) => widget.onToggle()),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.tab): () =>
                    widget.onAction(ItemAction.indent),
                const SingleActivator(
                  LogicalKeyboardKey.tab,
                  shift: true,
                ): () =>
                    widget.onAction(ItemAction.outdent),
                const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                    widget.onFocusStep(-1),
                const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                    widget.onFocusStep(1),
              },
              child: SwipeToIndent.keepMouseDrags(
                TextField(
                  controller: _text,
                  focusNode: widget.focusNode,
                  style: textStyle,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: widget.onTextChanged,
                  onSubmitted: (_) => widget.onSubmitted(),
                ),
              ),
            ),
          ),
          PopupMenuButton<ItemAction>(
            tooltip: 'Item actions',
            onSelected: widget.onAction,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ItemAction.indent, child: Text('Indent')),
              PopupMenuItem(value: ItemAction.outdent, child: Text('Outdent')),
              PopupMenuItem(value: ItemAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

/// A line that is not a checkbox item (heading, text), shown as is.
class ChecklistTextRow extends StatelessWidget {
  const ChecklistTextRow(this.line, {super.key});

  final ChecklistLine line;

  @override
  Widget build(BuildContext context) {
    final raw = line.raw.trim();
    final heading = raw.startsWith('#');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        heading ? raw.replaceFirst(RegExp(r'^#+\s*'), '') : raw,
        style: heading ? Theme.of(context).textTheme.titleMedium : null,
      ),
    );
  }
}
