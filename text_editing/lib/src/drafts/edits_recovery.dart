import 'package:collection/collection.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'fingerprint.dart';

/// Puts the edits a text file's page kept as [draft] into its file, at
/// the next start ([OwnDraftRecovery]): [own] holds the fingerprint of
/// the version the edits started from, and the content is the edited
/// text in that version's byte style.
///
/// The same rules as an open file that closes: the edits go into the
/// file if it is still that version (backed up first), else into a
/// conflict copy, also when the file is gone. Whether they are kept.
Future<bool> recoverEdits(
  FilesOfFolder files,
  Draft draft,
  OwnDraft own,
) async {
  final Draft(head: DraftHead(:path), :content) = draft;
  Future<bool> asConflict() async =>
      await files.saveAsConflict(path, content) is Ok;
  switch (await files.read(path)) {
    case Ok(value: final file)
        when const ListEquality<int>().equals(file.bytes, content):
      return true;
    case Ok(value: final file) when fingerprintOf(file.bytes) == own.part:
      // Best effort, like before an open file's first save.
      await files.backUpBeforeEdit(file);
      return switch (await files.replace(file.listed, content)) {
        Ok() => true,
        Err(error: StoreError.changedSinceRead) => await asConflict(),
        Err() => false,
      };
    case Ok() || Err(error: StoreError.notFound):
      return asConflict();
    case Err():
      return false;
  }
}
