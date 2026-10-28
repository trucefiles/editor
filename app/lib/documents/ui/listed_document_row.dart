import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../document.dart';
import '../document_colors.dart';
import '../previews/card_preview.dart';
import 'document_grid.dart';
import 'listed_document.dart';
import 'pin_or_color_sheet.dart';

/// A listed [document] as one row: title, place, last edit, pin, color
/// and conflict; opens it on tap.
class ListedDocumentRow extends ConsumerWidget {
  const ListedDocumentRow(this.document, {super.key});

  final Document document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(
      ref,
      document,
    );
    final theme = Theme.of(context);
    void onMark() => editPinOrColor(context, ref, document);
    // Right click with a mouse asks for a pin or color, as on cards.
    return GestureDetector(
      onSecondaryTap: onMark,
      child: ListTile(
        tileColor: documentTint(mark.color, theme.colorScheme),
        title: Text(
          cardTitle(document, preview),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: FolderBadge(document.folder, file: document.path),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Text(
              TimeTexts.of(context)
                  .edited(document.modified, now: DateTime.now()),
              style: theme.textTheme.labelSmall,
            ),
            if (settings.pinned)
              const Tooltip(
                message: 'Pinned',
                child: Icon(Icons.push_pin, size: 18),
              ),
            if (hasConflict) const ConflictLabel(),
          ],
        ),
        onTap: () => openNote(context, ref, document),
        onLongPress: onMark,
      ),
    );
  }
}
