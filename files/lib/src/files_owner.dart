import 'package:truce_core/truce_core.dart';

import 'file_steps.dart';
import 'files_contract.dart';

export 'files_contract.dart';

/// The owner of the user's actions on files (see
/// `files_contract.dart`); it has no state of its own to show.
typedef FilesOwner = Owner<FilesInput, Null, FilesAnswer>;

/// The app's files owner, and the answer to its first input: putting
/// the edits left by the last run into their files.
typedef Files = ({
  FilesOwner owner,
  Future<LeftEditsRecovered?> leftEditsRecovered,
});

/// The app's files owner by [steps], started: its first input
/// recovers the edits left before [startedAt], when the app started;
/// later ones belong to open files.
Files startFiles(FileSteps steps, {required DateTime startedAt}) {
  final owner = filesOwner(steps);
  return (
    owner: owner,
    leftEditsRecovered: ask<FilesInput, LeftEditsRecovered>(
      owner.send,
      owner.events,
      (ticket) => RecoverLeftEdits(ticket, before: startedAt),
    ),
  );
}

/// A files owner that runs each action by [steps].
FilesOwner filesOwner(FileSteps steps) =>
    SimpleOwner<FilesInput, Null, FilesAnswer>(
      null,
      (input, out) async => out.emit(await _run(steps, input)),
    );

/// Runs [input] by [steps]; its answer.
Future<FilesAnswer> _run(FileSteps steps, FilesInput input) => switch (input) {
  CreateFile(
    :final ticket,
    :final place,
    :final type,
    :final title,
    :final bytes,
    :final newSubfolder,
  ) =>
    steps
        .create(
          place,
          type: type,
          title: title,
          bytes: bytes,
          newSubfolder: newSubfolder,
        )
        .then((result) => FileCreated(ticket, result)),
  MoveFileTo(
    :final ticket,
    :final file,
    :final place,
    :final title,
    :final newSubfolder,
  ) =>
    steps
        .move(file, place, title: title, newSubfolder: newSubfolder)
        .then((result) => FileMoved(ticket, result)),
  DeleteFile(:final ticket, file: final file, :final bytes) =>
    steps.delete(file, bytes).then((result) => FileDeleted(ticket, result)),
  UndoDelete(:final ticket, :final deleted) =>
    steps.undoDelete(deleted).then((result) => DeleteUndone(ticket, result)),
  RestoreAsNewFile(
    :final ticket,
    :final backup,
    :final place,
    :final title,
    :final newSubfolder,
  ) =>
    steps
        .restoreAsNew(backup, place, title: title, newSubfolder: newSubfolder)
        .then((result) => RestoredAsNew(ticket, result)),
  SetMark(:final ticket, file: final file, :final mark) =>
    steps.setMark(file, mark).then((result) => MarkSet(ticket, result)),
  RecoverLeftEdits(:final ticket, :final before) =>
    steps
        .recoverLeftEdits(before: before)
        .then((_) => LeftEditsRecovered(ticket)),
};
