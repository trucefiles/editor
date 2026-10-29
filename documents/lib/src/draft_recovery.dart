import 'package:truce_core/truce_core.dart';

import 'document_draft.dart';
import 'document_drafts.dart';
import 'document_file_name.dart';
import 'document_files.dart';
import 'document_types.dart';
import 'open_failure.dart';

/// Puts edits kept on this device into their documents' files, for drafts left
/// when the app was ended before it could write them.
///
/// Same rules as an open document that closes: the edits go into the file if
/// it still holds the text they started from, else into a conflict copy.
/// A new document's file is created, as `DocumentFiles.create` does.
///
/// Works on one base folder's drafts. A draft no folder shows (e.g. after
/// the user narrowed a folder) stays, neither recovered nor deleted,
/// until a folder shows it again or its base folder goes.
final class DraftRecovery {
  const DraftRecovery(
    this._drafts, {
    required this._filesFor,
    required this._types,
  });

  final DocumentDrafts _drafts;

  /// The files of the folder that shows the document at a path; `null`
  /// if none does.
  final DocumentFiles? Function(RelPath path) _filesFor;

  final DocumentTypes _types;

  /// Recovers the drafts written before [before]; drafts that cannot be
  /// kept anywhere yet stay for the next try. Returns how many were kept.
  Future<int> recover({required DateTime before}) async {
    var kept = 0;
    for (final draft in await _drafts.all(before: before)) {
      final files = _filesFor(draft.path);
      if (files != null && await _keep(draft, files)) {
        await _drafts.remove(draft.id);
        kept++;
      }
    }
    return kept;
  }

  /// Whether [draft]'s edits are now in the file or in a conflict copy.
  Future<bool> _keep(DocumentDraft draft, DocumentFiles files) async {
    if (draft.base == null) return _create(draft, files);
    switch (await files.open(draft.path)) {
      case Ok(value: final document) when document.file.text == draft.text:
        return true;
      case Ok(value: final document) when document.file.text == draft.base:
        // Best effort, like before an open document's first save.
        await files.backUpBeforeEdit(document);
        return switch (await files.save(document, draft.text)) {
          Ok() => true,
          Err(error: StoreError.changedSinceRead) =>
            await files.saveAsConflict(document, draft.text) is Ok,
          Err() => false,
        };
      case Ok(value: final document):
        return await files.saveAsConflict(document, draft.text) is Ok;
      case Err(error: NotRead(error: StoreError.notFound)):
        return await files.saveAsConflictOfGone(draft.path, draft.text) is Ok;
      case Err():
        return false;
    }
  }

  /// Whether the new document of [draft] now has its file.
  Future<bool> _create(DocumentDraft draft, DocumentFiles files) async {
    final type = _types.of(draft.path);
    if (type == null) return false;
    // Created already, as the app was ended before it dropped the draft.
    if (await files.open(draft.path) case Ok(value: final document)
        when document.file.text == draft.text) {
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
