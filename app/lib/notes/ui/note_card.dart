import 'package:flutter/material.dart';

import '../../checklist/checklist_preview.dart';
import '../../folders/ui/folder_badge.dart';
import '../note.dart';
import '../note_title.dart';

/// A note in the grid: title, first lines (open items for checklists)
/// and its folder.
class NoteCard extends StatelessWidget {
  const NoteCard(this.note, {required this.onTap, super.key});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  checklistPreview(note.file.text) ??
                      notePreview(note.file.text),
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 8),
              FolderBadge(note.folder),
            ],
          ),
        ),
      ),
    );
  }
}
