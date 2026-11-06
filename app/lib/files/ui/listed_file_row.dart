import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/time_texts.dart';
import '../../conflicts/ui/conflict_label.dart';
import '../../folders/ui/folder_badge.dart';
import '../file_colors.dart';
import 'file_actions_menu.dart';
import 'file_type_icon.dart';
import 'listed_file.dart';
import 'open_file.dart';

/// A listed [file] as one row: its type's icon, title, place, last
/// edit, pin, color and conflict; opens it on tap.
class ListedFileRow extends ConsumerWidget {
  const ListedFileRow(this.file, {super.key});

  final ListedFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:preview, :mark, :settings, :hasConflict) = watchListed(ref, file);
    final theme = Theme.of(context);
    final title = cardTitle(file, preview);
    return HomeFileActions(
      file,
      title: title,
      pinned: settings.pinned,
      color: mark.color,
      // Right click with a mouse shows the actions' menu, as on cards.
      builder: (showSheet, showMenuAt) => GestureDetector(
        onSecondaryTapUp: (details) => showMenuAt(details.globalPosition),
        // The row's own Material holds its color: a tile color is drawn
        // on the screen's Material, behind the filter bar too, so it
        // showed there while the list scrolled.
        child: Material(
          color: fileTint(mark.color, theme.colorScheme) ?? Colors.transparent,
          child: ListTile(
            leading: FileTypeIcon(file),
            title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: FolderBadge(
              file.folder,
              file: file.path,
              cutInMiddle: true,
            ),
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
            onLongPress: showSheet,
          ),
        ),
      ),
    );
  }
}
