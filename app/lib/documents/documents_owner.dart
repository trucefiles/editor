import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import 'document_steps.dart';
import 'documents_contract.dart';

export 'documents_contract.dart';

/// The owner of the user's actions on documents (see
/// `documents_contract.dart`); it has no state of its own to show.
typedef DocumentsOwner = Owner<DocumentsInput, Null, DocumentsAnswer>;

/// The app's documents owner. Outlives every screen, so an undo still
/// works after the editor closed.
final documentsOwnerProvider = Provider<DocumentsOwner>((ref) {
  final owner = documentsOwner(ref.read(documentStepsProvider));
  ref.onDispose(() => unawaited(owner.close()));
  return owner;
});

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
  CreateDocument(:final ticket, :final place, :final title, :final text) =>
    steps
        .create(place, title: title, text: text)
        .then((result) => DocumentCreated(ticket, result)),
  MoveDocument(
    :final ticket,
    :final document,
    :final text,
    :final place,
    :final title,
  ) =>
    steps
        .move(document, text, place, title: title)
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
