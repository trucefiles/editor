import 'package:flutter/material.dart';

import '../text_format.dart';

/// Buttons that format the selected text and start a checklist.
class FormatToolbar extends StatelessWidget {
  const FormatToolbar({
    required this.onFormat,
    required this.onStartList,
    super.key,
  });

  final ValueChanged<TextFormat> onFormat;
  final VoidCallback onStartList;

  static const _formats = [
    (TextFormat.bold, Icons.format_bold, 'Bold (Ctrl+B)'),
    (TextFormat.italic, Icons.format_italic, 'Italic (Ctrl+I)'),
    (TextFormat.link, Icons.link, 'Link (Ctrl+K)'),
    (TextFormat.heading, Icons.title, 'Heading'),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
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
          IconButton(
            tooltip: 'Start list',
            icon: const Icon(Icons.checklist),
            onPressed: onStartList,
          ),
        ],
      ),
    ),
  );
}
