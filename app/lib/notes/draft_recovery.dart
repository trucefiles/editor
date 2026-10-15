import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folders_controller.dart';
import '../scan/folder_scans_controller.dart';
import 'note_draft.dart';
import 'note_drafts.dart';
import 'note_files.dart';

/// Puts edits kept on this device into their notes' files, for drafts left
/// when the app was ended before it could write them.
///
/// Same rules as an open note that closes: the edits go into the file if
/// it still holds the text they started from, else into a conflict copy.
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
    switch (await _files.open(draft.path)) {
      case Ok(value: final note) when note.file.text == draft.text:
        return true;
      case Ok(value: final note) when note.file.text == draft.base:
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
}

/// Recovers the drafts of every folder once per app run, then rescans if
/// any were kept. Drafts written after the app started belong to open
/// notes and are left alone.
final draftRecoveryProvider = FutureProvider<void>((ref) async {
  final startedAt = DateTime.now();
  final folders = await ref.read(foldersProvider.future);
  var kept = 0;
  for (final folder in folders) {
    kept += await DraftRecovery(
      ref.read(noteDraftsProvider(folder.id)),
      ref.read(noteFilesProvider(folder)),
    ).recover(before: startedAt);
  }
  if (kept > 0) await ref.read(folderScansProvider.notifier).refresh();
});
