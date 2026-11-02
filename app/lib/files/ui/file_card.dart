import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/card_frame.dart';
import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../file_colors.dart';

/// A file in the grid: title and first lines at the document text zoom
/// (as its [preview] has them, as many as fit); folder, last edit, pin and
/// color.
class FileCard extends StatelessWidget {
  const FileCard(
    this.file, {
    required this.preview,
    required this.onTap,
    required this.onMark,
    this.mark = FileMark.none,
    this.settings = FileSettings.defaults,
    this.hasConflict = false,
    super.key,
  });

  final ListedFile file;
  final CardPreview preview;
  final FileMark mark;

  /// The file's settings on this device: a pin, and how its preview
  /// shows.
  final FileSettings settings;

  /// Shows a badge: another version from a sync conflict is waiting.
  final bool hasConflict;

  final VoidCallback onTap;

  /// Asks for a pin or color: on long press, or right click with a mouse.
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    return CardFrame(
      color: fileTint(mark.color, theme.colorScheme),
      // An outline makes a conflict stand out in a full grid.
      shape: hasConflict
          ? (theme.cardTheme.shape as OutlinedBorder?)?.copyWith(
              side: BorderSide(color: theme.colorScheme.error, width: 2),
            )
          : null,
      onTap: onTap,
      onMark: onMark,
      title: cardTitle(file, preview),
      body: switch (preview) {
        Previewed(:final summary)
            when summary.preview(settings.view).isNotEmpty =>
          CardLines(summary.preview(settings.view)),
        PreviewNotText() => const CardLines(
          "Can't be shown as text.",
          italic: true,
        ),
        Previewed() || PreviewReading() || PreviewUnreadable() => null,
      },
      footer: Row(
        spacing: 6,
        children: [
          Expanded(child: FolderBadge(file.folder, file: file.path)),
          Text(
            TimeTexts.of(context).edited(file.modified, now: DateTime.now()),
            style: textTheme.labelSmall,
          ),
          if (settings.pinned)
            const Tooltip(
              message: 'Pinned',
              child: Icon(Icons.push_pin, size: cardFooterIconSize),
            ),
          if (hasConflict) const ConflictLabel(),
        ],
      ),
    );
  }
}
