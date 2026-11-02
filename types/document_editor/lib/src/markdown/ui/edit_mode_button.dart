import 'package:flutter/material.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// App bar button that shows the current [mode] and lets the user pick
/// another.
class EditModeButton extends StatelessWidget {
  const EditModeButton({
    required this.mode,
    required this.onChanged,
    super.key,
  });

  final EditMode mode;
  final ValueChanged<EditMode> onChanged;

  static IconData _icon(EditMode mode) => switch (mode) {
    EditMode.visual => Icons.edit_note,
    EditMode.markdown => Icons.code,
    EditMode.read => Icons.article_outlined,
  };

  static String _label(EditMode mode) => switch (mode) {
    EditMode.visual => 'Visual edit',
    EditMode.markdown => 'Markdown edit',
    EditMode.read => 'Read',
  };

  @override
  Widget build(BuildContext context) {
    final selected = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<EditMode>(
      tooltip: 'Mode: ${_label(mode)}',
      icon: Icon(_icon(mode)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in EditMode.values)
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
