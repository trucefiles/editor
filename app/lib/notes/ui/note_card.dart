import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/edited_time.dart';
import '../../conflicts/ui/conflict_label.dart';
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
    this.pinned = false,
    this.hasConflict = false,
    this.hideDone = false,
    super.key,
  });

  /// Most lines of the note a card shows.
  static const previewLines = 10;

  final Note note;
  final NoteMark mark;

  /// Shows a pin.
  final bool pinned;

  /// Shows a badge: another version from a sync conflict is waiting.
  final bool hasConflict;

  /// Leaves checked items out of the preview, counting them instead.
  final bool hideDone;

  final VoidCallback onTap;

  /// Asks for a pin or color: on long press, or right click with a mouse.
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final preview = notePreview(
      note.file.text,
      maxLines: previewLines,
      hideDone: hideDone,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      color: noteTint(mark.color, theme.colorScheme),
      // An outline makes a conflict stand out in a full grid.
      shape: hasConflict
          ? (theme.cardTheme.shape as OutlinedBorder?)?.copyWith(
              side: BorderSide(color: theme.colorScheme.error, width: 2),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMark,
        onSecondaryTap: onMark,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.title,
                style: textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  preview,
                  style: textTheme.bodySmall,
                  maxLines: previewLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
                  if (pinned)
                    const Tooltip(
                      message: 'Pinned',
                      child: Icon(Icons.push_pin, size: 18),
                    ),
                  if (hasConflict) const ConflictLabel(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
