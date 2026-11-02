import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../file_colors.dart';
import 'file_grid.dart';
import 'listed_file.dart';
import 'pin_or_color_sheet.dart';

/// A listed [file] as one row: title, place, last edit, pin, color
/// and conflict; opens it on tap.
class ListedFileRow extends ConsumerWidget {
  const ListedFileRow(this.file, {super.key});

  final ListedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(ref, file);
    final theme = Theme.of(context);
    void onMark() => editPinOrColor(context, ref, file);
    // Right click with a mouse asks for a pin or color, as on cards.
    return GestureDetector(
      onSecondaryTap: onMark,
      // The row's own Material holds its color: a tile color is drawn on
      // the screen's Material, behind the filter bar too, so it showed
      // there while the list scrolled.
      child: Material(
        color: fileTint(mark.color, theme.colorScheme) ?? Colors.transparent,
        child: ListTile(
          title: Text(
            cardTitle(file, preview),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: FolderBadge(file.folder, file: file.path),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Text(
                ref
                    .watch(timeTextsProvider)
                    .edited(file.modified, now: DateTime.now()),
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
          onTap: () => openFile(context, ref, file),
          onLongPress: onMark,
        ),
      ),
    );
  }
}
