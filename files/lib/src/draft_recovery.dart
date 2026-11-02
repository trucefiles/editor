import 'package:truce_core/truce_core.dart';

import 'file_draft.dart';
import 'file_drafts.dart';
import 'files_of_folder.dart';
import 'new_file_name.dart';
import 'open_failure.dart';
import 'shown_file_types.dart';

/// Puts edits kept on this device into their files' files, for drafts left
/// when the app was ended before it could write them.
///
/// Same rules as an open file that closes: the edits go into the file if
/// it still holds the text they started from, else into a conflict copy.
/// A new file is created, as `FilesOfFolder.create` does.
///
/// Works on one folder's drafts.
final class DraftRecovery {
  const DraftRecovery(
    this._drafts, {
    required this._files,
    required this._types,
  });

  final FileDrafts _drafts;

  /// The files of the drafts' folder.
  final FilesOfFolder _files;

  final ShownFileTypes _types;

  /// Recovers the drafts written before [before]; drafts that cannot be
  /// kept anywhere yet stay for the next try. Returns how many were kept.
  Future<int> recover({required DateTime before}) async {
    var kept = 0;
    for (final draft in await _drafts.all(before: before)) {
      if (await _keep(draft, _files)) {
        await _drafts.remove(draft.id);
        kept++;
      }
    }
    return kept;
  }

  /// Whether [draft]'s edits are now in the file or in a conflict copy.
  Future<bool> _keep(FileDraft draft, FilesOfFolder files) async {
    if (draft.base == null) return _create(draft, files);
    switch (await files.open(draft.path)) {
      case Ok(value: final file) when file.textFile.text == draft.text:
        return true;
      case Ok(value: final file) when file.textFile.text == draft.base:
        // Best effort, like before an open file's first save.
        await files.backUpBeforeEdit(file);
        return switch (await files.save(file, draft.text)) {
          Ok() => true,
          Err(error: StoreError.changedSinceRead) =>
            await files.saveAsConflict(file, draft.text) is Ok,
          Err() => false,
        };
      case Ok(value: final file):
        return await files.saveAsConflict(file, draft.text) is Ok;
      case Err(error: NotRead(error: StoreError.notFound)):
        return await files.saveAsConflictOfGone(draft.path, draft.text) is Ok;
      case Err():
        return false;
    }
  }

  /// Whether the new file of [draft] now has its file.
  Future<bool> _create(FileDraft draft, FilesOfFolder files) async {
    final type = _types.of(draft.path);
    if (type == null) return false;
    // Created already, as the app was ended before it dropped the draft.
    if (await files.open(draft.path) case Ok(value: final file)
        when file.textFile.text == draft.text) {
      return true;
    }
    final created = await files.create(
      splitFileName(draft.path.name).base,
      type: type,
      subfolder: draft.path.parent,
      newSubfolder: draft.newSubfolder,
      text: draft.text,
    );
    return created is Ok;
  }
}
