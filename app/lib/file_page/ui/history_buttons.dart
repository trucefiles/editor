import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// Undo and Redo for [editor], each on while it has a step to take;
/// Undo also takes a tap while off.
class HistoryButtons extends StatelessWidget {
  const HistoryButtons(this.editor, {super.key});

  final PageEditor editor;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: editor.changes,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Looks off with nothing to undo, but still takes a tap, which
        // then tells why there is nothing more.
        IconButton(
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
          color: editor.state.canUndo ? null : Theme.of(context).disabledColor,
          onPressed: () => editor.send(const Undo()),
        ),
        IconButton(
          tooltip: 'Redo',
          icon: const Icon(Icons.redo),
          onPressed: editor.state.canRedo
              ? () => editor.send(const Redo())
              : null,
        ),
      ],
    ),
  );
}
