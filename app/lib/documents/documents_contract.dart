/// The documents owner's contract: the user's actions on documents, each
/// answered once it is done. It runs them one at a time, in the order
/// sent, so two actions on one document never mix their steps.
library;

import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import 'delete_failure.dart';
import 'deleted_note.dart';
import 'document.dart';
import 'document_place.dart';
import 'move_failure.dart';

// Inputs.

sealed class DocumentsInput implements Asking {
  const DocumentsInput(this.ticket);

  @override
  final Ticket ticket;
}

/// Create a document of [type] holding [text] at [place], named after
/// [title].
final class CreateDocument extends DocumentsInput {
  const CreateDocument(
    super.ticket,
    this.place, {
    required this.type,
    required this.title,
    required this.text,
  });

  final DocumentPlace place;
  final DocumentType type;
  final String title;
  final String text;
}

/// Move [document], as last saved, to [place], renamed after [title] if
/// given.
final class MoveDocument extends DocumentsInput {
  const MoveDocument(super.ticket, this.document, this.place, {this.title});

  final Document document;
  final DocumentPlace place;
  final String? title;
}

/// Delete [document], holding [text], so it can be undone.
final class DeleteDocument extends DocumentsInput {
  const DeleteDocument(super.ticket, this.document, this.text);

  final Document document;
  final String text;
}

/// Write [deleted] back as it was.
final class UndoDelete extends DocumentsInput {
  const UndoDelete(super.ticket, this.deleted);

  final DeletedNote deleted;
}

/// Give [document] the color [mark].
final class SetMark extends DocumentsInput {
  const SetMark(super.ticket, this.document, this.mark);

  final Document document;
  final DocumentMark mark;
}

/// Put the drafts written before [before] into their files; the owner's
/// first input, before the first scan.
final class RecoverDrafts extends DocumentsInput {
  const RecoverDrafts(super.ticket, {required this.before});

  final DateTime before;
}

// Events: one answer per input.

sealed class DocumentsAnswer implements Answering {
  const DocumentsAnswer(this.ticket);

  @override
  final Ticket ticket;
}

final class DocumentCreated extends DocumentsAnswer {
  const DocumentCreated(super.ticket, this.result);

  final Result<Document, StoreError> result;
}

final class DocumentMoved extends DocumentsAnswer {
  const DocumentMoved(super.ticket, this.result);

  final Result<Document, MoveFailure> result;
}

final class DocumentDeleted extends DocumentsAnswer {
  const DocumentDeleted(super.ticket, this.result);

  final Result<DeletedNote, DeleteFailure> result;
}

final class DeleteUndone extends DocumentsAnswer {
  const DeleteUndone(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class MarkSet extends DocumentsAnswer {
  const MarkSet(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class DraftsRecovered extends DocumentsAnswer {
  const DraftsRecovered(super.ticket);
}
