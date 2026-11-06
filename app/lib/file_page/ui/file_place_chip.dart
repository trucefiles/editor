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

/// Shows where the open file is, e.g. `Files/inbox/Milk.md`;
/// tapping it asks for another folder, subfolder or name. A new file
/// only changes where its file will go; one with a file is moved or
/// renamed.
class FilePlaceChip extends ConsumerWidget {
  const FilePlaceChip(this.session, {required this.enabled, super.key});

  final FileSession session;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = session.file;
    return Tooltip(
      message: 'Location and name',
      child: ActionChip(
        label: FolderBadge(file.folder, file: session.path, withName: true),
        onPressed: enabled ? () => _edit(context, ref) : null,
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
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
        await _move(context, to);
    }
  }

  /// Moves or renames the file [to]. Asked at once, so leaving right
  /// after still moves it; the file owner saves the edits first, so the
  /// move takes them along.
  Future<void> _move(BuildContext context, MoveTarget to) async {
    final moved = await session.move(to);
    if (!context.mounted) return;
    showSnack(context, switch (moved) {
      Ok(value: final copy) =>
        'Saved as ${placeName(copy.folder, copy.path.parent)}/'
            '${copy.path.name}',
      Err(:final error) => moveFailureText(error),
    });
  }
}
