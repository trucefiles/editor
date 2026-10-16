import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../scan/folder_scans.dart';
import '../../scan/folder_scans_controller.dart';
import '../note_folder.dart';

/// One row per folder that [scans] could not read in full: folders that
/// failed, with a retry, and folders with subfolders that can't be read.
class FolderProblems extends ConsumerWidget {
  const FolderProblems(this.scans, {required this.folders, super.key});

  final FolderScans scans;

  /// The folders the user added, for the names of [FolderScans.unreadable].
  final List<NoteFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (final MapEntry(key: folder, value: error)
          in scans.failedFolders.entries)
        ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(folder.name),
          subtitle: Text(error.text),
          trailing: TextButton(
            onPressed: ref.read(folderScansProvider.notifier).refresh,
            child: const Text('Retry'),
          ),
        ),
      for (final folder in folders)
        if (scans.unreadable[folder.id] case final subfolders?)
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(folder.name),
            subtitle: Text(
              "Can't read ${_names(subfolders)}; its notes aren't shown.",
            ),
          ),
    ],
  );

  static String _names(List<RelPath> subfolders) =>
      subfolders.map((subfolder) => subfolder.value).join(', ');
}
