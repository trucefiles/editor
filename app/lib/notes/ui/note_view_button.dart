import 'package:flutter/material.dart';

import '../note_view.dart';

/// App bar button that shows the current [view] and lets the user pick
/// another.
class NoteViewButton extends StatelessWidget {
  const NoteViewButton({
    required this.view,
    required this.onChanged,
    super.key,
  });

  final NoteView view;
  final ValueChanged<NoteView> onChanged;

  static IconData _icon(NoteView view) => switch (view) {
    NoteView.text => Icons.notes,
    NoteView.list => Icons.checklist,
    NoteView.rendered => Icons.article_outlined,
  };

  static String _label(NoteView view) => switch (view) {
    NoteView.text => 'Text',
    NoteView.list => 'List',
    NoteView.rendered => 'Rendered',
  };

  @override
  Widget build(BuildContext context) {
    final selected = Theme.of(context).colorScheme.primary;
    return PopupMenuButton<NoteView>(
      tooltip: 'View: ${_label(view)}',
      icon: Icon(_icon(view)),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final option in NoteView.values)
          PopupMenuItem(
            value: option,
            child: Row(
              spacing: 12,
              children: [
                Icon(_icon(option), color: option == view ? selected : null),
                Text(
                  _label(option),
                  style: option == view ? TextStyle(color: selected) : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
