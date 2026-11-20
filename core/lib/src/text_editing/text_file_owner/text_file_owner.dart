import '../../conflicts/text_merge.dart';
import '../../owners/effects.dart';
import '../../owners/machine.dart';
import '../../owners/machine_owner.dart';
import '../../owners/owner.dart';
import '../version.dart';
import 'text_file_contract.dart';
import 'text_file_state.dart';
import 'text_file_transition.dart';
import 'text_file_work.dart';

export 'text_file_contract.dart';
export 'text_file_state.dart' show TextFileState;

/// The owner of one open file (see `file_contract.dart`),
/// over versions of kind [V].
typedef TextFileOwner<V extends Version> =
    Owner<TextFileInput<V>, TextFileState<V>, TextFileEvent>;

/// The file owner's machine.
typedef TextFileMachine<V extends Version> =
    Machine<
      TextFileMessage<V>,
      TextFileState<V>,
      TextFileWork<V>,
      TextFileEvent,
      TextFileEffect<V>
    >;

/// Carries out the file owner's effects.
typedef TextFileEffectHandler<V extends Version> =
    EffectHandler<TextFileEffect<V>, TextFileResult<V>>;

/// The file owner of [machine], its effects carried out by [handle].
TextFileOwner<V> textFileOwner<V extends Version>(
  TextFileMachine<V> machine,
  TextFileEffectHandler<V> handle,
) =>
    MachineOwner<
      TextFileMessage<V>,
      TextFileInput<V>,
      TextFileResult<V>,
      TextFileState<V>,
      TextFileWork<V>,
      TextFileEvent,
      TextFileEffect<V>
    >(machine, handle: handle);

/// The file machine of a file opened as [opened]. [merge]: how its
/// type merges two texts, if it does, for the user's pick of both merged
/// when the file changed elsewhere.
TextFileMachine<V> openedTextFile<V extends Version>(
  Seen<V> opened, {
  TextMerge? merge,
}) => Machine(
  state: TextFileState(
    status: const InStep(),
    text: opened.text,
    rev: 0,
    file: opened.version,
  ),
  work: TextFileWork(expected: opened, offered: [opened]),
  step: _stepWith(merge),
);

/// The file machine of a new file, which has no file yet and starts with
/// [start]; [merge] as for [openedTextFile].
TextFileMachine<V> newTextFile<V extends Version>({
  String start = '',
  TextMerge? merge,
}) => Machine(
  state: TextFileState(
    status: const Unwritten(),
    text: start,
    rev: 0,
    file: null,
  ),
  work: TextFileWork(expected: null, offered: const [], start: start),
  step: _stepWith(merge),
);

/// The file machine's step, picks of both merged by [merge].
Step<TextFileState<V>, TextFileWork<V>, TextFileEvent, TextFileEffect<V>>
Function(TextFileState<V>, TextFileWork<V>, TextFileMessage<V>)
_stepWith<V extends Version>(TextMerge? merge) =>
    (state, work, message) => fileStep(state, work, message, merge: merge);
