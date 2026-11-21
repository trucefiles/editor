import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../files/text_file_type.dart';
import '../files/text_files.dart';
import 'old_draft.dart';

/// Puts the edits an older app version kept as drafts ([OldDraft]) into
/// their files, by its rules: into the file if it still holds the text
/// they started from, else into a conflict copy; a new file is created.
/// Only until such drafts are all recovered.
final class OldDraftRecovery {
  const OldDraftRecovery(
    this._drafts, {
    required this._files,
    required this._types,
  });

  final OldDrafts _drafts;
  final TextFiles _files;
  final ShownFileTypes _types;

  /// Recovers the drafts written before [before]; those that can't be
  /// kept anywhere yet stay for the next try.
  Future<void> recover({required DateTime before}) async {
    for (final draft in (await _drafts.all(before: before) ?? []).nonNulls) {
      if (await _keep(draft)) await _drafts.remove(draft.id);
    }
  }

  /// Whether [draft]'s edits are now in the file or in a conflict copy.
  Future<bool> _keep(OldDraft draft) async {
    final type = _types.of(draft.path);
    if (type is! TextFileType) return false;
    final opened = await _files.open(draft.path);
    if (opened case Ok(value: final file) when file.text == draft.text) {
      return true;
    }
    if (draft.base == null) {
      return await _files.create(
        splitFileName(draft.path.name).base,
        type: type,
        subfolder: draft.path.parent,
        newSubfolder: draft.newSubfolder,
        text: draft.text,
      ) is Ok;
    }
    switch (opened) {
      case Ok(value: final file) when file.text == draft.base:
        await _files.backUpBeforeEdit(file);
        return switch (await _files.save(file, draft.text)) {
          Ok() => true,
          Err(error: StoreError.changedSinceRead) =>
            await _files.saveAsConflict(file, draft.text) is Ok,
          Err() => false,
        };
      case Ok(value: final file):
        return await _files.saveAsConflict(file, draft.text) is Ok;
      case Err(error: NotRead(error: StoreError.notFound)):
        return await _files.saveAsConflictOfGone(
          draft.path,
          draft.text,
          style: type.newFile,
        ) is Ok;
      case Err():
        return false;
    }
  }
}

/// The files steps' recovery of the drafts an older app version left
/// ([FilesWork.recoverOldDrafts]): each folder's [draftsOf], put into
/// its files by their [types].
Future<void> Function(FilesOfFolder files, {required DateTime before})
recoverOldDraftsWith(
  OldDrafts Function(FolderId folder) draftsOf,
  ShownFileTypes types,
) =>
    (files, {required before}) => OldDraftRecovery(
      draftsOf(files.folder.id),
      files: TextFiles(files),
      types: types,
    ).recover(before: before);
