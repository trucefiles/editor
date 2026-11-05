import '../../conflicts/text_merge.dart';
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

/// The owner of one open file (see `file_contract.dart`),
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

/// The file machine of a file opened as [opened]. [merge]: how its
/// type merges two texts, if it does, for the user's pick of both merged
/// when the file changed elsewhere.
FileMachine<V> openedFile<V extends Version>(
  Seen<V> opened, {
  TextMerge? merge,
}) => Machine(
  state: FileState(
    status: const InStep(),
    text: opened.text,
    rev: 0,
    file: opened.version,
  ),
  work: FileWork(expected: opened, offered: [opened]),
  step: _stepWith(merge),
);

/// The file machine of a new file, which has no file yet and starts with
/// [start]; [merge] as for [openedFile].
FileMachine<V> newFile<V extends Version>({
  String start = '',
  TextMerge? merge,
}) => Machine(
  state: FileState(status: const Unwritten(), text: '', rev: 0, file: null),
  work: FileWork(expected: null, offered: const [], start: start),
  step: _stepWith(merge),
);

/// The file machine's step, picks of both merged by [merge].
Step<FileState<V>, FileWork<V>, FileEvent, FileEffect<V>> Function(
  FileState<V>,
  FileWork<V>,
  FileMessage<V>,
)
_stepWith<V extends Version>(TextMerge? merge) =>
    (state, work, message) => fileStep(state, work, message, merge: merge);
