import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folder_selection.dart';
import '../note_folder.dart';
import 'folder_badge.dart';

/// "All" plus one chip per folder; picks the folder the grid shows.
class FolderFilterBar extends ConsumerWidget {
  const FolderFilterBar(this.folders, {super.key});

  final List<NoteFolder> folders;

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
              label: Text(folder.name),
              selected: selected == folder.id,
              onSelected: (_) => selection.choose(folder.id),
            ),
        ],
      ),
    );
  }
}
