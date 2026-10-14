import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/edited_time.dart';
import '../../folders/ui/folder_badge.dart';
import '../note.dart';
import '../note_colors.dart';
import '../note_title.dart';

/// A note in the grid: title, first lines, folder, last edit, pin and
/// color.
class NoteCard extends StatelessWidget {
  const NoteCard(
    this.note, {
    required this.onTap,
    required this.onMark,
    this.mark = NoteMark.none,
    this.hasConflict = false,
    super.key,
  });

  final Note note;
  final NoteMark mark;

  /// Shows a badge: another version from a sync conflict is waiting.
  final bool hasConflict;

  final VoidCallback onTap;

  /// Asks for a pin or color: on long press, or right click with a mouse.
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      color: noteTint(mark.color, theme.colorScheme),
      child: InkWell(
        onTap: onTap,
        onLongPress: onMark,
        onSecondaryTap: onMark,
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
                  notePreview(note.file.text),
                  style: textTheme.bodySmall,
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  Expanded(child: FolderBadge(note.folder, file: note.path)),
                  Text(
                    editedTime(
                      MaterialLocalizations.of(context),
                      note.modified,
                      now: DateTime.now(),
                    ),
                    style: textTheme.labelSmall,
                  ),
                  if (mark.pinned)
                    const Tooltip(
                      message: 'Pinned',
                      child: Icon(Icons.push_pin, size: 18),
                    ),
                  if (hasConflict)
                    Tooltip(
                      message: 'Sync conflict',
                      child: Icon(
                        Icons.call_split,
                        size: 18,
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
