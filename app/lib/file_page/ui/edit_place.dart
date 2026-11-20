import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../files/file_actions.dart';
import '../../files/ui/file_place_dialog.dart';
import '../../files/ui/folders_to_place_in.dart';
import '../../files/ui/move_failure_text.dart';
import '../../folders/ui/folder_badge.dart';

/// Asks the user for another folder, subfolder or name of an open file,
/// at [at] with its name field as [nameField], then has the page [take]
/// it; says where the file was saved, or why it can't go.
Future<void> editPlace(
  BuildContext context,
  WidgetRef ref, {
  required FilePlace at,
  required ({String name, String hint}) nameField,
  required Future<Result<ListedFile?, MoveFailure>> Function(PickedPlace) take,
}) async {
  final folders = await foldersToPlaceIn(context, ref);
  if (folders == null || !context.mounted) return;
  final actions = ref.read(fileActionsProvider);
  final picked = await showFileNameDialog(
    context,
    folders: folders,
    initial: at,
    name: nameField.name,
    nameHint: nameField.hint,
    subfoldersOf: actions.subfoldersOf,
    canHold: actions.canHold,
  );
  if (picked == null || !context.mounted) return;
  // Taken at once, so leaving right after still takes it.
  final taken = await take(picked);
  if (!context.mounted) return;
  switch (taken) {
    case Ok(value: final moved?):
      showSnack(
        context,
        'Saved as ${placeName(moved.folder, moved.path.parent)}/'
        '${moved.path.name}',
      );
    case Ok():
      return;
    case Err(:final error):
      showSnack(context, moveFailureText(error));
  }
}
