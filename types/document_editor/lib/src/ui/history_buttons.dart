import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// Undo and Redo for [editor], each on while it has a step to take.
class HistoryButtons extends StatelessWidget {
  const HistoryButtons(this.editor, {super.key});

  final PageEditor editor;

  @override
  Widget build(BuildContext context) => StreamBuilder(
    stream: editor.changes,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
          onPressed: editor.state.canUndo
              ? () => editor.send(const Undo())
              : null,
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
