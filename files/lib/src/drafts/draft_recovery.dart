import 'package:truce_core/truce_core.dart';

import '../files_of_folder.dart';
import 'draft.dart';
import 'file_drafts.dart';

/// Puts one [OwnDraft] into its file, as the user that kept it does;
/// whether it is now kept in the folder (in its file or a conflict
/// copy). One that is not stays for the next start.
typedef OwnDraftRecovery = Future<bool> Function(
  FilesOfFolder files,
  Draft draft,
  OwnDraft own,
);

/// Puts what the last run left waiting on this device into one folder's
/// files, before anything else runs: a new file is written as it would
/// have been ([FilesOfFolder.createOnce]); an [OwnDraft] goes to
/// [recoverOwn]. Each draft is removed once kept; one that can't be kept
/// yet stays for the next try.
Future<void> recoverFolderDrafts(
  FileDrafts drafts,
  FilesOfFolder files, {
  required OwnDraftRecovery recoverOwn,
  required DateTime before,
}) async {
  for (final head in await drafts.heads(before: before)) {
    // One draft's content at a time: some may be large (e.g. photos).
    final content = await drafts.content(head);
    if (content == null) continue;
    final draft = Draft(head, content);
    final kept = switch (head.of) {
      NewFileDraft(:final newSubfolder) => await files.createOnce(
        head.path,
        content,
        newSubfolder: newSubfolder,
      ) is Ok,
      final OwnDraft own => await recoverOwn(files, draft, own),
    };
    if (kept) await drafts.remove(head.id);
  }
}
