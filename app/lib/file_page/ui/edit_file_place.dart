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

/// Asks the user for another folder, subfolder or name of the file
/// [session] has open, then takes it: a new file only changes where its
/// file will go; one with a file is moved or renamed.
Future<void> editFilePlace(
  BuildContext context,
  WidgetRef ref,
  FileSession session,
) async {
  final folders = await foldersToPlaceIn(context, ref);
  if (folders == null || !context.mounted) return;
  final actions = ref.read(fileActionsProvider);
  final nameField = nameFieldOf(
    session.file,
    session.path,
    session.summary.firstLine,
  );
  final picked = await showFileNameDialog(
    context,
    folders: folders,
    initial: (folder: session.file.folder, subfolder: session.path.parent),
    name: nameField.name,
    nameHint: nameField.hint,
    subfoldersOf: actions.subfoldersOf,
    canHold: actions.canHold,
  );
  if (picked == null || !context.mounted) return;
  // Read after the dialog: hiding the app meanwhile creates the file.
  switch (PlaceChange.of(
    session.file,
    saved: session.read,
    firstLine: session.summary.firstLine,
    picked: picked,
  )) {
    case NewPlace(:final to):
      session.place(to);
    case SamePlace():
      return;
    case CantMove(:final failure):
      showSnack(context, moveFailureText(failure));
    case MoveTo(:final to):
      await _move(context, session, to);
  }
}

/// Moves or renames [session]'s file [to]. Asked at once, so leaving
/// right after still moves it; the file owner saves the edits first, so
/// the move takes them along.
Future<void> _move(
  BuildContext context,
  FileSession session,
  MoveTarget to,
) async {
  final moved = await session.move(to);
  if (!context.mounted) return;
  showSnack(context, switch (moved) {
    Ok(value: final copy) =>
      'Saved as ${placeName(copy.folder, copy.path.parent)}/'
          '${copy.path.name}',
    Err(:final error) => moveFailureText(error),
  });
}
