import 'package:flutter/material.dart';

import '../folder_colors.dart';

/// The folder colors to pick one from; [selected] is ticked.
class FolderColorPicker extends StatelessWidget {
  const FolderColorPicker({
    required this.selected,
    required this.onPicked,
    super.key,
  });

  final Color selected;
  final ValueChanged<Color> onPicked;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final color in folderColors)
        InkResponse(
          onTap: () => onPicked(color),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: color.toARGB32() == selected.toARGB32()
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        ),
    ],
  );
}
