import 'package:truce_core/truce_core.dart';

import 'document_draft.dart';
import 'document_drafts.dart';
import 'document_file_name.dart';
import 'document_files.dart';

/// Puts edits kept on this device into their documents' files, for drafts left
/// when the app was ended before it could write them.
///
/// Same rules as an open document that closes: the edits go into the file if
/// it still holds the text they started from, else into a conflict copy.
/// A new document's file is created, as `DocumentFiles.create` does.
final class DraftRecovery {
  const DraftRecovery(this._drafts, this._files);

  final DocumentDrafts _drafts;
  final DocumentFiles _files;

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
  Future<bool> _keep(DocumentDraft draft) async {
    if (draft.base == null) return _create(draft);
    switch (await _files.open(draft.path)) {
      case Ok(value: final document) when document.file.text == draft.text:
        return true;
      case Ok(value: final document) when document.file.text == draft.base:
        // Best effort, like before an open document's first save.
        await _files.backUpBeforeEdit(document);
        return switch (await _files.save(document, draft.text)) {
          Ok() => true,
          Err(error: StoreError.changedSinceRead) =>
            await _files.saveAsConflict(document, draft.text) is Ok,
          Err() => false,
        };
      case Ok(value: final document):
        return await _files.saveAsConflict(document, draft.text) is Ok;
      case Err(error: StoreError.notFound):
        return await _files.saveAsConflictOfGone(draft.path, draft.text) is Ok;
      case Err():
        return false;
    }
  }

  /// Whether the new document of [draft] now has its file.
  Future<bool> _create(DocumentDraft draft) async {
    // Created already, as the app was ended before it dropped the draft.
    if (await _files.open(draft.path) case Ok(value: final document)
        when document.file.text == draft.text) {
      return true;
    }
    final created = await _files.create(
      splitFileName(draft.path.name).base,
      subfolder: draft.path.parent,
      text: draft.text,
    );
    return created is Ok;
  }
}
