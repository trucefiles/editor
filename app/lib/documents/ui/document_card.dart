import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../../text_zoom/ui/document_text_zoom.dart';
import '../document.dart';
import '../document_card_summary.dart';
import '../document_colors.dart';

/// A document in the grid: title and first lines at the document text zoom;
/// folder, last edit, pin and color.
class DocumentCard extends StatelessWidget {
  const DocumentCard(
    this.document, {
    required this.onTap,
    required this.onMark,
    this.mark = DocumentMark.none,
    this.pinned = false,
    this.hasConflict = false,
    this.hideDone = false,
    super.key,
  });

  final Document document;
  final DocumentMark mark;

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
    final preview = document.preview(hideDone: hideDone);
    return Card(
      clipBehavior: Clip.antiAlias,
      color: documentTint(mark.color, theme.colorScheme),
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
              DocumentTextZoom(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      document.title,
                      style: textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (preview.isNotEmpty)
                      Text(
                        preview,
                        style: textTheme.bodySmall,
                        maxLines: DocumentCardSummary.previewLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                spacing: 6,
                children: [
                  Expanded(
                    child: FolderBadge(document.folder, file: document.path),
                  ),
                  Text(
                    TimeTexts.of(context)
                        .edited(document.modified, now: DateTime.now()),
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
