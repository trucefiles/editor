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

/// The owner of one open document's file (see `file_contract.dart`),
/// over versions of kind [V].
typedef FileOwner<V extends Version> =
    Owner<FileInput<V>, FileState<V>, FileEvent>;

/// The file owner's machine.
typedef FileMachine<V extends Version> =
    Machine<
      FileMessage<V>,
      FileState<V>,
      FileWork<V>,
      FileEvent,
      FileEffect<V>
    >;

/// Carries out the file owner's effects.
typedef FileEffectHandler<V extends Version> =
    EffectHandler<FileEffect<V>, FileResult<V>>;

/// The file owner of [machine], its effects carried out by [handle].
FileOwner<V> fileOwner<V extends Version>(
  FileMachine<V> machine,
  FileEffectHandler<V> handle,
) =>
    MachineOwner<
      FileMessage<V>,
      FileInput<V>,
      FileResult<V>,
      FileState<V>,
      FileWork<V>,
      FileEvent,
      FileEffect<V>
    >(machine, handle: handle);

/// The file machine of a document opened as [opened].
FileMachine<V> openedFile<V extends Version>(Seen<V> opened) => Machine(
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
FileMachine<V> newFile<V extends Version>() => Machine(
  state: FileState(status: const Unwritten(), text: '', rev: 0, file: null),
  work: FileWork(expected: null, offered: const []),
  step: fileStep,
);
