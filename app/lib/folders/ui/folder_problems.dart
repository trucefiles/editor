import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../folder_state/folder_state_controller.dart';

/// One row per folder that could not be seen in full in [contents]: folders that
/// failed, with a retry, folders with subfolders that can't be read, and
/// folders whose chosen subfolders are gone.
class FolderProblems extends ConsumerWidget {
  const FolderProblems(this.contents, {required this.folders, super.key});

  final FolderContents contents;

  /// The folders the user added, for the names of [FolderContents.unreadable]
  /// and [FolderContents.gone].
  final List<DocumentFolder> folders;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (final MapEntry(key: folder, value: error)
          in contents.failedFolders.entries)
        ListTile(
          leading: const Icon(Icons.error_outline),
          title: Text(folder.name),
          subtitle: Text(error.text),
          trailing: TextButton(
            onPressed: ref.read(folderContentsProvider.notifier).refresh,
            child: const Text('Retry'),
          ),
        ),
      for (final folder in folders)
        if (contents.unreadable[folder.id] case final subfolders?)
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(folder.name),
            subtitle: Text(
              "${_names(subfolders)} can't be read, so the documents there aren't shown.",
            ),
          ),
      for (final folder in folders)
        if (contents.gone[folder.id] case final subfolders?)
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(folder.name),
            subtitle: Text(
              subfolders.length == 1
                  ? '${_names(subfolders)} is gone. Change the folder to '
                        'pick another one.'
                  : '${_names(subfolders)} are gone. Change the folder to '
                        'pick others.',
            ),
          ),
    ],
  );

  static String _names(List<RelPath> subfolders) =>
      subfolders.map((subfolder) => subfolder.value).join(', ');
}
