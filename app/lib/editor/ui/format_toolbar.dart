import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../text_format.dart';

/// Buttons that format the selected text, turn the selected lines into a
/// list of a kind, and break the line within its block. A bar at the
/// bottom of the screen: its buttons stay clear of the system's bottom
/// edge (e.g. Android's gesture line), its color goes under it.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar({
    required this.onFormat,
    required this.onList,
    required this.onLineBreak,
    super.key,
  });

  final ValueChanged<TextFormat> onFormat;
  final ValueChanged<ListKind> onList;
  final VoidCallback onLineBreak;

  static const _formats = [
    (TextFormat.bold, Icons.format_bold, 'Bold (Ctrl+B)'),
    (TextFormat.italic, Icons.format_italic, 'Italic (Ctrl+I)'),
    (TextFormat.link, Icons.link, 'Link (Ctrl+K)'),
    (TextFormat.heading, Icons.title, 'Heading'),
  ];

  static const _lists = [
    (ListKind.checkbox, Icons.checklist, 'Checklist'),
    (ListKind.bullet, Icons.format_list_bulleted, 'Bulleted list'),
    (ListKind.numbered, Icons.format_list_numbered, 'Numbered list'),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (format, icon, label) in _formats)
              IconButton(
                tooltip: label,
                icon: Icon(icon),
                onPressed: () => onFormat(format),
              ),
            for (final (kind, icon, label) in _lists)
              IconButton(
                tooltip: label,
                icon: Icon(icon),
                onPressed: () => onList(kind),
              ),
            IconButton(
              tooltip: 'Line break (Shift+Enter)',
              icon: const Icon(Icons.keyboard_return),
              onPressed: onLineBreak,
            ),
          ],
        ),
      ),
    ),
  );
}
