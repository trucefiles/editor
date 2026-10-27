import '../../owners/effects.dart';
import '../../owners/machine.dart';
import '../../owners/machine_owner.dart';
import '../../owners/owner.dart';
import '../version.dart';
import 'file_contract.dart';
import 'file_state.dart';
import 'file_transition.dart';
import 'file_work.dart';

export 'file_contract.dart';
export 'file_state.dart' show FileState;

/// The owner of one open document's file (see `file_contract.dart`).
typedef FileOwner = Owner<FileInput, FileState, FileEvent>;

/// The file owner's machine.
typedef FileMachine =
    Machine<FileMessage, FileState, FileWork, FileEvent, FileEffect>;

/// Carries out the file owner's effects.
typedef FileEffectHandler = EffectHandler<FileEffect, FileResult>;

/// The file owner of [machine], its effects carried out by [handle].
FileOwner fileOwner(FileMachine machine, FileEffectHandler handle) =>
    MachineOwner<
      FileMessage,
      FileInput,
      FileResult,
      FileState,
      FileWork,
      FileEvent,
      FileEffect
    >(machine, handle: handle);

/// The file machine of a document opened as [opened].
FileMachine openedFile(Seen opened) => Machine(
  state: FileState(
    status: const InStep(),
    text: opened.text,
    rev: 0,
    file: opened.version,
  ),
  work: FileWork(expected: opened, offered: [opened]),
  step: fileStep,
);

/// The file machine of a new document, which has no file yet.
FileMachine newFile() => const Machine(
  state: FileState(status: Unwritten(), text: '', rev: 0, file: null),
  work: FileWork(expected: null, offered: []),
  step: fileStep,
);
