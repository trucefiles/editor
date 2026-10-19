import 'package:flutter/material.dart';

import '../../editor/note_mode.dart';

/// App bar button that shows the current [mode] and lets the user pick
/// another.
class NoteModeButton extends StatelessWidget {
  const NoteModeButton({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final NoteMode mode;
  final ValueChanged<NoteMode> onChanged;

  static IconData _icon(NoteMode mode) => switch (mode) {
    NoteMode.visual => Icons.edit_note,
    NoteMode.markdown => Icons.code,
    NoteMode.read => Icons.article_outlined,
  };

  static String _label(NoteMode mode) => switch (mode) {
    NoteMode.visual => 'Visual edit',
    NoteMode.markdown => 'Markdown edit',
    NoteMode.read => 'Read',
  };

  @override
  Widget build(BuildContext context) {
    final selected = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<NoteMode>(
      tooltip: 'Mode: ${_label(mode)}',
      icon: Icon(_icon(mode)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in NoteMode.values)
          PopupMenuItem(
            value: option,
            child: Row(
              spacing: 12,
              children: [
                Icon(_icon(option), color: option == mode ? selected : null),
                Text(
                  _label(option),
                  style: option == mode ? TextStyle(color: selected) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
