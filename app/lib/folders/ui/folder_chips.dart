import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/clear_chip.dart';
import '../folder_selection.dart';
import 'folder_badge.dart';
import 'folder_warning_icon.dart';

/// A row of one chip per folder, in the user's order; picks the folders the grid
/// shows, none picked showing all; a Clear chip first while some are
/// picked. A chip shows its folder's conflicts
/// and a sign if its sync tool warns about it.
class FolderChips extends ConsumerWidget {
  const FolderChips(
    this.folders, {
    required this.conflictCount,
    required this.padding,
    super.key,
  });

  final List<Folder> folders;

  /// Pending sync conflicts in a folder, shown on its chip.
  final int Function(Folder folder) conflictCount;

  /// Space around the chips.
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final picked = ref.watch(pickedFoldersProvider);
    final picks = ref.read(pickedFoldersProvider.notifier);
    return ChipRow(
      padding: padding,
      chips: [
        if (picked.isNotEmpty) ClearChip(onPressed: picks.clear),
        for (final folder in folders)
          FilterChip(
            showCheckmark: false,
            avatar: FolderDot(folder.color),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                switch (conflictCount(folder)) {
                  0 => Text(folder.name),
                  final count => Badge.count(
                    count: count,
                    offset: const Offset(16, -8),
                    child: Text(folder.name),
                  ),
                },
                FolderWarningIcon(folder),
              ],
            ),
            selected: picked.contains(folder.id),
            onSelected: (_) => picks.toggle(folder.id),
          ),
      ],
    );
  }
}
