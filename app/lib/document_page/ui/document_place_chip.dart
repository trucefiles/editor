import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/snack.dart';
import '../../documents/document_actions.dart';
import '../../documents/document_file_name.dart';
import '../../documents/document_place.dart';
import '../../documents/document_title.dart';
import '../../documents/move_failure.dart';
import '../../documents/ui/document_place_dialog.dart';
import '../../documents/ui/move_failure_text.dart';
import '../../folders/folders_controller.dart';
import '../../folders/ui/folder_badge.dart';
import '../../scan/folder_scans_controller.dart';
import '../document_file.dart';
import '../document_session.dart';

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
        label: FolderBadge(
          file.folder,
          file: file.pathFor(session.text),
          withName: true,
        ),
        onPressed: enabled ? () => _edit(context, ref) : null,
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    // Change events don't tell about new empty subfolders; a rescan finds
    // them, so the dialog offers them.
    await ref.read(folderScansProvider.notifier).refresh();
    if (!context.mounted) return;
    final actions = ref.read(documentActionsProvider);
    final folders = actions.reachableOf(ref.read(foldersProvider).value ?? []);
    if (folders.isEmpty) {
      return showSnack(context, 'No folder can be reached right now.');
    }
    final file = session.file;
    final path = file.pathFor(session.text);
    final picked = await showNoteFileDialog(
      context,
      folders: folders,
      initial: (folder: file.folder, subfolder: path.parent),
      name: switch (file) {
        NewFile() => file.titleFor(session.text),
        ExistingFile() => splitFileName(path.name).base,
      },
      subfoldersOf: actions.subfoldersOf,
    );
    if (picked == null || !context.mounted) return;
    // Read after the dialog: hiding the app meanwhile creates the file.
    if (session.file is NewFile) {
      final name = picked.name.trim();
      return session.place(
        NewFile(picked.place, name: name.isEmpty ? null : name),
      );
    }
    await _move(context, actions, picked.place, picked.name);
  }

  /// Moves or renames the document's file; an empty [name] names it after
  /// the first line. Only a document saved in its folder moves, so the
  /// move takes every edit along.
  Future<void> _move(
    BuildContext context,
    DocumentActions actions,
    DocumentPlace place,
    String name,
  ) async {
    await session.secure(SecureReason.hide);
    if (!context.mounted) return;
    final current = session.document;
    if (current == null || session.status is! InStep) {
      return showSnack(
        context,
        'Please wait until the document is saved in its folder.',
      );
    }
    // Read after the dialog and the save, so no edit is left behind.
    final text = session.text;
    final title = name.trim().isEmpty ? documentTitleLine(text) : name.trim();
    if (place.folder.id == current.folder.id &&
        place.subfolder == current.path.parent &&
        isNamedAfter(current.path.name, title)) {
      return;
    }
    final moved = await actions.move(current, text, place, title: title);
    if (!context.mounted) return;
    switch (moved) {
      case Ok(value: final copy):
        session.moved(copy);
        showSnack(
          context,
          'Saved as ${placeName(copy.folder, copy.path.parent)}/'
          '${copy.path.name}',
        );
      case Err(error: MoveLeftOriginal(:final copy) && final error):
        session.moved(copy);
        showSnack(context, moveFailureText(error));
      case Err(:final error):
        showSnack(context, moveFailureText(error));
    }
  }
}
