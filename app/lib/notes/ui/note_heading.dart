import 'package:flutter/material.dart';

import '../../common/edited_time.dart';
import '../../folders/note_folder.dart';
import '../../folders/ui/folder_badge.dart';

/// The editor's title: the note's title, its folder and its last edit.
class NoteHeading extends StatelessWidget {
  const NoteHeading({
    required this.title,
    required this.folder,
    required this.edited,
    super.key,
  });

  final String title;
  final NoteFolder folder;
  final DateTime edited;

  @override
  Widget build(BuildContext context) {
    final time = editedTime(
      MaterialLocalizations.of(context),
      edited,
      now: DateTime.now(),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, overflow: TextOverflow.ellipsis),
        Row(
          spacing: 8,
          children: [
            Flexible(child: FolderBadge(folder)),
            Text('Edited $time', style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}
