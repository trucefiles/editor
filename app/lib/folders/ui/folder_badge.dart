import 'package:flutter/material.dart';

import '../note_folder.dart';

/// The folder's color dot and name, so it is always clear where a note
/// lives.
class FolderBadge extends StatelessWidget {
  const FolderBadge(this.folder, {super.key});

  final NoteFolder folder;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FolderDot(folder.color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            folder.name,
            style: Theme.of(context).textTheme.labelSmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class FolderDot extends StatelessWidget {
  const FolderDot(this.color, {super.key, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
