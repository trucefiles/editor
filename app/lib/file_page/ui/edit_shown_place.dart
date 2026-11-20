import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/snack.dart';
import '../../files/file_actions.dart';
import '../../files/ui/file_place_dialog.dart';
import '../../files/ui/folders_to_place_in.dart';
import '../../files/ui/move_failure_text.dart';
import '../../folders/ui/folder_badge.dart';
import '../view_page_controller.dart';

/// Asks the user for another folder, subfolder or name of the file on
/// the view page [page], then takes it: a new file only changes where
/// it will go; one in its folder is moved or renamed. An empty name
/// keeps the name it has.
Future<void> editShownPlace(
  BuildContext context,
  WidgetRef ref,
  ViewPageController page,
) async {
  final at = page.place;
  if (at == null) return;
  final folders = await foldersToPlaceIn(context, ref);
  if (folders == null || !context.mounted) return;
  final actions = ref.read(fileActionsProvider);
  final picked = await showFileNameDialog(
    context,
    folders: folders,
    initial: (folder: at.folder, subfolder: at.path.parent),
    name: page.title,
    nameHint: page.title,
    subfoldersOf: actions.subfoldersOf,
    canHold: actions.canHold,
  );
  if (picked == null || !context.mounted) return;
  final name = picked.name.trim();
  final moving = page.listed != null;
  final failure = await page.moveTo(
    picked.place,
    title: name.isEmpty ? page.title : name,
    newSubfolder: picked.newSubfolder,
  );
  if (!context.mounted) return;
  final now = page.place;
  if (failure != null) {
    showSnack(context, moveFailureText(failure));
  } else if (moving &&
      now != null &&
      (now.path != at.path || now.folder.id != at.folder.id)) {
    showSnack(
      context,
      'Saved as ${placeName(now.folder, now.path.parent)}/${now.path.name}',
    );
  }
}
