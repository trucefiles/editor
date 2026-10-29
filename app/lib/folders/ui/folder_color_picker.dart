import 'package:flutter/material.dart';

import '../folder_colors.dart';

/// The folder colors to pick one from, by name; [selected] is ticked.
class FolderColorPicker extends StatelessWidget {
  const FolderColorPicker({
    required this.selected,
    required this.onPicked,
    super.key,
  });

  final String selected;
  final ValueChanged<String> onPicked;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final MapEntry(key: name, value: color) in folderColors.entries)
        InkResponse(
          onTap: () => onPicked(name),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: name == selected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        ),
    ],
  );
}
