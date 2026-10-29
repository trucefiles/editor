import 'package:truce_core/truce_core.dart';

import 'document_steps.dart';
import 'documents_contract.dart';

export 'documents_contract.dart';

/// The owner of the user's actions on documents (see
/// `documents_contract.dart`); it has no state of its own to show.
typedef DocumentsOwner = Owner<DocumentsInput, Null, DocumentsAnswer>;

/// The app's documents owner, and the answer to its first input: putting
/// the drafts left by the last run into their files.
typedef Documents = ({
  DocumentsOwner owner,
  Future<DraftsRecovered?> draftsRecovered,
});

/// The app's documents owner by [steps], started: its first input
/// recovers the drafts written before [startedAt], when the app started;
/// later ones belong to open documents.
Documents startDocuments(DocumentSteps steps, {required DateTime startedAt}) {
  final owner = documentsOwner(steps);
  return (
    owner: owner,
    draftsRecovered: ask<DocumentsInput, DraftsRecovered>(
      owner.send,
      owner.events,
      (ticket) => RecoverDrafts(ticket, before: startedAt),
    ),
  );
}

/// A documents owner that runs each action by [steps].
DocumentsOwner documentsOwner(DocumentSteps steps) =>
    SimpleOwner<DocumentsInput, Null, DocumentsAnswer>(
      null,
      (input, out) async => out.emit(await _run(steps, input)),
    );

/// Runs [input] by [steps]; its answer.
Future<DocumentsAnswer> _run(
  DocumentSteps steps,
  DocumentsInput input,
) => switch (input) {
  CreateDocument(
    :final ticket,
    :final place,
    :final type,
    :final title,
    :final text,
    :final newSubfolder,
  ) =>
    steps
        .create(
          place,
          type: type,
          title: title,
          text: text,
          newSubfolder: newSubfolder,
        )
        .then((result) => DocumentCreated(ticket, result)),
  MoveDocument(
    :final ticket,
    :final document,
    :final place,
    :final title,
    :final newSubfolder,
  ) =>
    steps
        .move(document, place, title: title, newSubfolder: newSubfolder)
        .then((result) => DocumentMoved(ticket, result)),
  DeleteDocument(:final ticket, :final document, :final text) =>
    steps
        .delete(document, text)
        .then((result) => DocumentDeleted(ticket, result)),
  UndoDelete(:final ticket, :final deleted) =>
    steps.undoDelete(deleted).then((result) => DeleteUndone(ticket, result)),
  SetMark(:final ticket, :final document, :final mark) =>
    steps.setMark(document, mark).then((result) => MarkSet(ticket, result)),
  RecoverDrafts(:final ticket, :final before) =>
    steps.recoverDrafts(before: before).then((_) => DraftsRecovered(ticket)),
};
