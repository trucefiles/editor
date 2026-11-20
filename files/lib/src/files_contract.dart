/// The files owner's contract: the user's actions on files, each
/// answered once it is done. It runs them one at a time, in the order
/// sent, so two actions on one file never mix their steps.
library;

import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'backups/folder_backups.dart';
import 'delete_failure.dart';
import 'file_bytes.dart';
import 'file_place.dart';
import 'listed_file.dart';
import 'move_failure.dart';
import 'undoable_delete.dart';

// Inputs.

sealed class FilesInput implements Asking {
  const FilesInput(this.ticket);

  @override
  final Ticket ticket;
}

/// Create a file holding [bytes] at [place], named after [title] with
/// [extension] (with its dot); first [place]'s subfolder if it is a new
/// one the user asked for ([newSubfolder]).
final class CreateFile extends FilesInput {
  const CreateFile(
    super.ticket,
    this.place, {
    required this.extension,
    required this.title,
    required this.bytes,
    this.newSubfolder = false,
  });

  final FilePlace place;
  final String extension;
  final String title;
  final Uint8List bytes;
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

  final FileBytes file;
  final FilePlace place;
  final String? title;
  final bool newSubfolder;
}

/// Delete [file], holding [bytes], so it can be undone.
final class DeleteFile extends FilesInput {
  const DeleteFile(super.ticket, this.file, this.bytes);

  final ListedFile file;
  final Uint8List bytes;
}

/// Write [deleted] back as it was.
final class UndoDelete extends FilesInput {
  const UndoDelete(super.ticket, this.deleted);

  final UndoableDelete deleted;
}

/// Write [backup] as a new file at [place], named after [title] if
/// given; first make [place]'s subfolder if it is a new one the user asked
/// for ([newSubfolder]).
final class RestoreAsNewFile extends FilesInput {
  const RestoreAsNewFile(
    super.ticket,
    this.backup,
    this.place, {
    this.title,
    this.newSubfolder = false,
  });

  final FolderBackup backup;
  final FilePlace place;
  final String? title;
  final bool newSubfolder;
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

  final Result<FileBytes, StoreError> result;
}

final class FileMoved extends FilesAnswer {
  const FileMoved(super.ticket, this.result);

  final Result<FileBytes, MoveFailure> result;
}

final class FileDeleted extends FilesAnswer {
  const FileDeleted(super.ticket, this.result);

  final Result<UndoableDelete, DeleteFailure> result;
}

final class DeleteUndone extends FilesAnswer {
  const DeleteUndone(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class RestoredAsNew extends FilesAnswer {
  const RestoredAsNew(super.ticket, this.result);

  final Result<FileBytes, StoreError> result;
}

final class MarkSet extends FilesAnswer {
  const MarkSet(super.ticket, this.result);

  final Result<void, StoreError> result;
}

final class DraftsRecovered extends FilesAnswer {
  const DraftsRecovered(super.ticket);
}
