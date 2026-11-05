import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/snack.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folders_controller.dart';
import '../file_actions.dart';

/// The folders a file can be placed in now, for a place dialog: listed
/// first, as change events don't tell about new empty subfolders and a
/// listing finds them. `null` once the screen is gone, or after telling
/// the user that no folder can be reached.
Future<List<Folder>?> foldersToPlaceIn(
  BuildContext context,
  WidgetRef ref,
) async {
  await ref.read(folderContentsProvider.notifier).refresh();
  if (!context.mounted) return null;
  final folders = ref
      .read(fileActionsProvider)
      .reachableOf(ref.read(foldersProvider).value ?? []);
  if (folders.isNotEmpty) return folders;
  showSnack(context, 'No folder can be reached right now.');
  return null;
}
