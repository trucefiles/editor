import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_folders/truce_folders.dart';

import '../folder_selection.dart';
import 'folder_badge.dart';
import 'folder_warning_icon.dart';

/// "All" plus one chip per folder; picks the folder the grid shows. A
/// chip shows its folder's conflicts and a sign if its sync tool warns
/// about it.
class FolderFilterBar extends ConsumerWidget {
  const FolderFilterBar(this.folders, {required this.conflictCount, super.key});

  final List<DocumentFolder> folders;

  /// Pending sync conflicts in a folder, shown on its chip.
  final int Function(DocumentFolder folder) conflictCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedFolderIdProvider);
    final selection = ref.read(selectedFolderIdProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        spacing: 8,
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: selected == null,
            onSelected: (_) => selection.choose(null),
          ),
          for (final folder in folders)
            ChoiceChip(
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
              selected: selected == folder.id,
              onSelected: (_) => selection.choose(folder.id),
            ),
        ],
      ),
    );
  }
}
