import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folders_controller.dart';
import 'note_draft.dart';
import 'note_drafts.dart';
import 'note_file_name.dart';
import 'note_files.dart';

/// Puts edits kept on this device into their notes' files, for drafts left
/// when the app was ended before it could write them.
///
/// Same rules as an open note that closes: the edits go into the file if
/// it still holds the text they started from, else into a conflict copy.
/// A new note's file is created, at its folder's top level if its
/// subfolder is gone.
final class DraftRecovery {
  const DraftRecovery(this._drafts, this._files);

  final NoteDrafts _drafts;
  final NoteFiles _files;

  /// Recovers the drafts written before [before]; drafts that cannot be
  /// kept anywhere yet stay for the next try. Returns how many were kept.
  Future<int> recover({required DateTime before}) async {
    var kept = 0;
    for (final draft in await _drafts.all(before: before)) {
      if (await _keep(draft)) {
        await _drafts.remove(draft.id);
        kept++;
      }
    }
    return kept;
  }

  /// Whether [draft]'s edits are now in the file or in a conflict copy.
  Future<bool> _keep(NoteDraft draft) async {
    if (draft.base == null) return _create(draft);
    switch (await _files.open(draft.path)) {
      case Ok(value: final note) when note.file.text == draft.text:
        return true;
      case Ok(value: final note) when note.file.text == draft.base:
        // Best effort, like before an open note's first save.
        await _files.backUpBeforeEdit(note);
        return switch (await _files.save(note, draft.text)) {
          Ok() => true,
          Err(error: StoreError.changedSinceRead) =>
            await _files.saveAsConflict(note, draft.text) is Ok,
          Err() => false,
        };
      case Ok(value: final note):
        return await _files.saveAsConflict(note, draft.text) is Ok;
      case Err(error: StoreError.notFound):
        return await _files.saveAsConflictOfGone(draft.path, draft.text) is Ok;
      case Err():
        return false;
    }
  }

  /// Whether the new note of [draft] now has its file.
  Future<bool> _create(NoteDraft draft) async {
    // Created already, as the app was ended before it dropped the draft.
    if (await _files.open(draft.path) case Ok(value: final note)
        when note.file.text == draft.text) {
      return true;
    }
    final title = splitFileName(draft.path.name).base;
    final subfolder = draft.path.parent;
    var created = await _files.create(
      title,
      subfolder: subfolder,
      text: draft.text,
    );
    if (created case Err(error: StoreError.notFound) when subfolder != null) {
      created = await _files.create(title, text: draft.text);
    }
    return created is Ok;
  }
}

/// Recovers the drafts of every folder once per app run, before the first
/// scan, so no note opens with its old text while its draft is pending.
/// Drafts written after the app started belong to open notes and are left
/// alone.
final draftRecoveryProvider = FutureProvider<void>((ref) async {
  final startedAt = DateTime.now();
  final folders = await ref.read(foldersProvider.future);
  for (final folder in folders) {
    await DraftRecovery(
      ref.read(noteDraftsProvider(folder.id)),
      ref.read(noteFilesProvider(folder)),
    ).recover(before: startedAt);
  }
});
