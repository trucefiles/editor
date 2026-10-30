import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/snack.dart';
import '../../documents/document_actions.dart';
import '../../documents/ui/document_place_dialog.dart';
import '../../documents/ui/move_failure_text.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';

/// Shows where the open document's file is, e.g. `Documents/inbox/Milk.md`;
/// tapping it asks for another folder, subfolder or name. A new document
/// only changes where its file will go; one with a file is moved or
/// renamed.
class DocumentPlaceChip extends ConsumerWidget {
  const DocumentPlaceChip(this.session, {required this.enabled, super.key});

  final DocumentSession session;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final file = session.file;
    return Tooltip(
      message: 'Place and name',
      child: ActionChip(
        label: FolderBadge(file.folder, file: session.path, withName: true),
        onPressed: enabled ? () => _edit(context, ref) : null,
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    // Change events don't tell about new empty subfolders; a listing finds
    // them, so the dialog offers them.
    await ref.read(folderContentsProvider.notifier).refresh();
    if (!context.mounted) return;
    final actions = ref.read(documentActionsProvider);
    final folders = actions.reachableOf(ref.read(foldersProvider).value ?? []);
    if (folders.isEmpty) {
      return showSnack(context, 'No folder can be reached right now.');
    }
    final file = session.file;
    final path = session.path;
    final picked = await showDocumentFileDialog(
      context,
      folders: folders,
      initial: (folder: file.folder, subfolder: path.parent),
      name: switch (file) {
        NewFile() => file.titleFor(session.summary.firstLine),
        ExistingFile() => splitFileName(path.name).base,
      },
      subfoldersOf: actions.subfoldersOf,
      canHold: actions.canHold,
    );
    if (picked == null || !context.mounted) return;
    // Read after the dialog: hiding the app meanwhile creates the file.
    if (session.file case NewFile(:final type)) {
      final name = picked.name.trim();
      return session.place(
        NewFile(
          picked.place,
          type: type,
          name: name.isEmpty ? null : name,
          newSubfolder: picked.newSubfolder,
        ),
      );
    }
    await _move(context, picked);
  }

  /// Moves or renames the document's file; an empty [name] names it after
  /// the first line. Asked at once, so leaving right after still moves it;
  /// the file owner saves the edits first, so the move takes them along.
  Future<void> _move(BuildContext context, PickedPlace picked) async {
    final (:place, :name, :newSubfolder) = picked;
    final current = session.document;
    if (current == null) {
      return showSnack(context, moveFailureText(const MoveNotSaved()));
    }
    final title = name.trim().isEmpty ? session.summary.firstLine : name.trim();
    if (place.folder.id == current.folder.id &&
        place.subfolder == current.path.parent &&
        isNamedAfter(current.path.name, title)) {
      return;
    }
    final moved = await session.move((
      place: place,
      title: title,
      newSubfolder: newSubfolder,
    ));
    if (!context.mounted) return;
    showSnack(context, switch (moved) {
      Ok(value: final copy) =>
        'Saved as ${placeName(copy.folder, copy.path.parent)}/'
            '${copy.path.name}',
      Err(:final error) => moveFailureText(error),
    });
  }
}
