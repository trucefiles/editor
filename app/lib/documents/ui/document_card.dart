import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../document_colors.dart';
import 'card_frame.dart';

/// A document in the grid: title and first lines at the document text zoom
/// (as its [preview] has them, as many as fit); folder, last edit, pin and
/// color.
class DocumentCard extends StatelessWidget {
  const DocumentCard(
    this.document, {
    required this.preview,
    required this.onTap,
    required this.onMark,
    this.mark = DocumentMark.none,
    this.settings = DocumentSettings.defaults,
    this.hasConflict = false,
    super.key,
  });

  final Document document;
  final CardPreview preview;
  final DocumentMark mark;

  /// The document's settings on this device: a pin, and how its preview
  /// shows.
  final DocumentSettings settings;

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
      color: documentTint(mark.color, theme.colorScheme),
      // An outline makes a conflict stand out in a full grid.
      shape: hasConflict
          ? (theme.cardTheme.shape as OutlinedBorder?)?.copyWith(
              side: BorderSide(color: theme.colorScheme.error, width: 2),
            )
          : null,
      onTap: onTap,
      onMark: onMark,
      title: cardTitle(document, preview),
      body: switch (preview) {
        Previewed(:final summary)
            when summary.preview(settings.view).isNotEmpty =>
          CardLines(summary.preview(settings.view), style: textTheme.bodySmall),
        PreviewNotText() => CardLines(
          "Can't be shown as text.",
          style: textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
        ),
        Previewed() || PreviewReading() || PreviewUnreadable() => null,
      },
      footer: Row(
        spacing: 6,
        children: [
          Expanded(child: FolderBadge(document.folder, file: document.path)),
          Text(
            TimeTexts.of(context)
                .edited(document.modified, now: DateTime.now()),
            style: textTheme.labelSmall,
          ),
          if (settings.pinned)
            const Tooltip(
              message: 'Pinned',
              child: Icon(Icons.push_pin, size: 18),
            ),
          if (hasConflict) const ConflictLabel(),
        ],
      ),
    );
  }
}
