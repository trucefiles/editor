import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../files/file_actions.dart';
import '../../files/ui/file_place_dialog.dart';
import '../../files/ui/folders_to_place_in.dart';
import '../../folders/ui/folder_badge.dart';

/// Asks where [backup] goes and under what name, starting at its file's
/// old place, then writes it there as a new file, never over one; tells
/// how it went.
Future<void> restoreAsNew(
  BuildContext context,
  WidgetRef ref,
  FolderBackup backup,
) async {
  final folders = await foldersToPlaceIn(context, ref);
  if (folders == null || !context.mounted) return;
  final actions = ref.read(fileActionsProvider);
  final (:folder, backup: kept) = backup;
  final oldName = splitFileName(kept.filePath.name).base;
  final picked = await showFileNameDialog(
    context,
    title: 'Restore as new file',
    action: 'Restore',
    folders: folders,
    initial: (folder: folder, subfolder: kept.filePath.parent),
    name: oldName,
    nameHint: oldName,
    subfoldersOf: actions.subfoldersOf,
    canHold: actions.canHold,
  );
  if (picked == null || !context.mounted) return;
  final (:place, :name, :newSubfolder) = picked;
  final restored = await actions.restoreAsNew(
    backup,
    place,
    title: name.trim().isEmpty ? null : name,
    newSubfolder: newSubfolder,
  );
  if (restored case Ok(value: final copy)) {
    actions.reveal(place, copy.type.type);
  }
  if (!context.mounted) return;
  showSnack(context, switch (restored) {
    Ok(value: final copy) =>
      'Restored as ${placeName(copy.folder, copy.path.parent)}/'
          '${copy.path.name}',
    Err(error: BackupNotText()) => "This backup can't be shown as text.",
    Err(error: NotRestored(:final error)) => error.text,
  });
}
