import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../scan/folder_scans_controller.dart';
import '../move_failure.dart';
import '../note_actions.dart';
import '../note_edit_session.dart';
import '../note_file_name.dart';
import '../note_place.dart';
import '../note_title.dart';
import '../open_note.dart';
import 'move_failure_text.dart';
import 'note_place_dialog.dart';

/// Shows where [note]'s file is, e.g. `Notes/inbox/Milk.md`; tapping it
/// asks for another folder, subfolder or name. A new note only changes
/// where its file will go; a note with a file is moved or renamed.
class NotePlaceChip extends ConsumerWidget {
  const NotePlaceChip(this.note, {required this.enabled, super.key});

  final OpenNote note;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Tooltip(
    message: 'Place and name',
    child: ActionChip(
      label: FolderBadge(note.folder, file: note.path, withName: true),
      onPressed: enabled ? () => _edit(context, ref) : null,
    ),
  );

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    // Change events don't tell about new empty subfolders; a rescan finds
    // them, so the dialog offers them.
    await ref.read(folderScansProvider.notifier).refresh();
    if (!context.mounted) return;
    final actions = ref.read(noteActionsProvider);
    final folders = actions.reachableOf(ref.read(foldersProvider).value ?? []);
    if (folders.isEmpty) {
      return showSnack(context, 'No folder can be reached right now.');
    }
    final picked = await showNoteFileDialog(
      context,
      folders: folders,
      initial: (folder: note.folder, subfolder: note.path.parent),
      name: note.pending?.title ?? splitFileName(note.path.name).base,
      subfoldersOf: actions.subfoldersOf,
    );
    if (picked == null || !context.mounted) return;
    // Read after the dialog: hiding the app meanwhile creates the file.
    if (note.pending case final pending?) {
      return pending.moveTo(picked.place, title: picked.name);
    }
    await _move(context, actions, picked.place, picked.name);
  }

  /// Moves or renames the note's file; an empty [name] names it after the
  /// first line. Only a note saved in its folder moves, so the move takes
  /// every edit along.
  Future<void> _move(
    BuildContext context,
    NoteActions actions,
    NotePlace place,
    String name,
  ) async {
    await note.flush();
    if (!context.mounted) return;
    if (note.state != EditState.saved) {
      return showSnack(
        context,
        'Please wait until the note is saved in its folder.',
      );
    }
    // Read after the dialog and the flush, so no edit is left behind.
    final current = note.note!;
    final text = note.text;
    final title = name.trim().isEmpty ? noteTitleLine(text) : name.trim();
    if (place.folder.id == current.folder.id &&
        place.subfolder == current.path.parent &&
        isNamedAfter(current.path.name, title)) {
      return;
    }
    final moved = await actions.move(current, text, place, title: title);
    if (!context.mounted) return;
    switch (moved) {
      case Ok(value: final copy):
        note.moved(copy);
        showSnack(
          context,
          'Saved as ${placeName(copy.folder, copy.path.parent)}/'
          '${copy.path.name}',
        );
      case Err(error: MoveLeftOriginal(:final copy) && final error):
        note.moved(copy);
        showSnack(context, moveFailureText(error));
      case Err(:final error):
        showSnack(context, moveFailureText(error));
    }
  }
}
