/// The files owner's contract: the user's actions on files, each
/// answered once it is done. It runs them one at a time, in the order
/// sent, so two actions on one file never mix their steps.
library;

import 'package:truce_core/truce_core.dart';

import 'delete_failure.dart';
import 'file_place.dart';
import 'file_text.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'shown_file_type.dart';
import 'undoable_delete.dart';

// Inputs.

sealed class FilesInput implements Asking {
  const FilesInput(this.ticket);

  @override
  final Ticket ticket;
}

/// Create a file of [type] holding [text] at [place], named after
/// [title]; first [place]'s subfolder if it is a new one the user asked
/// for ([newSubfolder]).
final class CreateFile extends FilesInput {
  const CreateFile(
    super.ticket,
    this.place, {
    required this.type,
    required this.title,
    required this.text,
    this.newSubfolder = false,
  });

  final FilePlace place;
  final ShownFileType type;
  final String title;
  final String text;
  final bool newSubfolder;
}

/// Move [file], as last saved, to [place], renamed after [title] if
/// given; first make [place]'s subfolder if it is a new one the user asked
/// for ([newSubfolder]).
final class MoveFileTo extends FilesInput {
  const MoveFileTo(
    super.ticket,
    this.file,
    this.place, {
    this.title,
    this.newSubfolder = false,
  });

  final FileText file;
  final FilePlace place;
  final String? title;
  final bool newSubfolder;
}

/// Delete [file], holding [text], so it can be undone.
final class DeleteFile extends FilesInput {
  const DeleteFile(super.ticket, this.file, this.text);

  final FileText file;
  final String text;
}

/// Write [deleted] back as it was.
final class UndoDelete extends FilesInput {
  const UndoDelete(super.ticket, this.deleted);

  final UndoableDelete deleted;
}

/// Give [file] the color [mark].
final class SetMark extends FilesInput {
  const SetMark(super.ticket, this.file, this.mark);

  final ListedFile file;
  final FileMark mark;
}

/// Put the drafts written before [before] into their files; the owner's
/// first input, before the first scan.
final class RecoverDrafts extends FilesInput {
  const RecoverDrafts(super.ticket, {required this.before});

  final DateTime before;
}

// Events: one answer per input.

sealed class FilesAnswer implements Answering {
  const FilesAnswer(this.ticket);

  @override
  final Ticket ticket;
}

final class FileCreated extends FilesAnswer {
  const FileCreated(super.ticket, this.result);

  final Result<FileText, StoreError> result;
}

final class FileMoved extends FilesAnswer {
  const FileMoved(super.ticket, this.result);

  final Result<FileText, MoveFailure> result;
}

final class FileDeleted extends FilesAnswer {
  const FileDeleted(super.ticket, this.result);

  final Result<UndoableDelete, DeleteFailure> result;
}

final class DeleteUndone extends FilesAnswer {
  const DeleteUndone(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class MarkSet extends FilesAnswer {
  const MarkSet(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class DraftsRecovered extends FilesAnswer {
  const DraftsRecovered(super.ticket);
}
