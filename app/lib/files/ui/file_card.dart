import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/card_frame.dart';
import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../file_colors.dart';
import 'file_type_icon.dart';

/// A file in the grid: title and first lines at the document text zoom
/// (as its [preview] has them, as many as fit); its type's icon first in
/// the footer, so it keeps its place, then the folder, which takes the
/// room left, last edit, pin and color.
class FileCard extends ConsumerWidget {
  const FileCard(
    this.file, {
    required this.preview,
    required this.onTap,
    required this.onActions,
    required this.onActionsAt,
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

  /// Asks for the file's actions on a long press.
  final VoidCallback onActions;

  /// Asks for the file's actions on a right click, at its point on the
  /// screen.
  final ValueChanged<Offset> onActionsAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return CardFrame(
      color: fileTint(mark.color, theme.colorScheme),
      // An outline makes a conflict stand out in a full grid.
      shape: hasConflict
          ? (theme.cardTheme.shape as OutlinedBorder?)?.copyWith(
              side: BorderSide(color: theme.colorScheme.error, width: 2),
            )
          : null,
      onTap: onTap,
      onActions: onActions,
      onActionsAt: onActionsAt,
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
      footer: _Footer(
        file,
        edited: ref
            .watch(timeTextsProvider)
            .edited(file.modified, now: DateTime.now()),
        pinned: settings.pinned,
        hasConflict: hasConflict,
      ),
    );
  }
}

/// The type's icon first, so it keeps its place; the file's place takes
/// the room the rest leaves; the last edit, pin and conflict at the end.
/// Where even they don't fit, the place is gone and the date is cut.
class _Footer extends StatelessWidget {
  const _Footer(
    this.file, {
    required this.edited,
    required this.pinned,
    required this.hasConflict,
  });

  final ListedFile file;
  final String edited;
  final bool pinned;
  final bool hasConflict;

  static const _gap = 6.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Row(
      spacing: _gap,
      children: [
        FileTypeIcon(file, size: cardFooterIconSize),
        Expanded(
          child: FolderBadge(file.folder, file: file.path, cutInMiddle: true),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: max(
              0,
              constraints.maxWidth - cardFooterIconSize - 2 * _gap,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: _gap,
            children: [
              Flexible(
                child: Text(
                  edited,
                  style: Theme.of(context).textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (pinned)
                const Tooltip(
                  message: 'Pinned',
                  child: Icon(Icons.push_pin, size: cardFooterIconSize),
                ),
              // Its word would leave the place no room; the red outline
              // and the tooltip say it.
              if (hasConflict) const ConflictLabel(word: false),
            ],
          ),
        ),
      ],
    ),
  );
}
