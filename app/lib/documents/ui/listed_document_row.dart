import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../document_colors.dart';
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
      // The row's own Material holds its color: a tile color is drawn on
      // the screen's Material, behind the filter bar too, so it showed
      // there while the list scrolled.
      child: Material(
        color:
            documentTint(mark.color, theme.colorScheme) ?? Colors.transparent,
        child: ListTile(
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
          onTap: () => openDocument(context, ref, document),
          onLongPress: onMark,
        ),
      ),
    );
  }
}
