import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show Redo, Undo;

import '../editor_gate.dart';

/// Undo and Redo for the editor behind [gate], each on while it has a
/// step to take.
class HistoryButtons extends StatelessWidget {
  const HistoryButtons(this.gate, {super.key});

  final EditorGate gate;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: gate,
    builder: (context, _) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
          onPressed: gate.state.canUndo ? () => undo(gate) : null,
        ),
        IconButton(
          tooltip: 'Redo',
          icon: const Icon(Icons.redo),
          onPressed: gate.state.canRedo ? () => redo(gate) : null,
        ),
      ],
    ),
  );
}

/// Undoes the latest step of the editor behind [gate].
void undo(EditorGate gate) => gate.send((now) => Undo(revision: now.revision));

/// Redoes the step undone last.
void redo(EditorGate gate) => gate.send((now) => Redo(revision: now.revision));
