import 'package:truce_core/truce_core.dart'
    show EditorBook, Machine, MachineOwner, Owner, StartTimer, Version;

import 'plain_contract.dart';
import 'plain_transition.dart';

export 'plain_contract.dart';

/// The owner of the text one open plain text document's editor shows
/// (see `plain_contract.dart`).
typedef PlainOwner = Owner<PlainInput, PlainState, PlainNotice>;

/// The plain editor owner's machine; its work is its edits' bookkeeping,
/// with the texts undo comes back to.
typedef PlainMachine =
    Machine<
      PlainMessage,
      PlainState,
      EditorBook<String>,
      PlainNotice,
      PlainSaveTimer
    >;

/// The editor owner of a plain text document holding [text], read as
/// [version] (`null` for a new document); its only effects are the save
/// timers, which [startTimer] starts (a fake clock in tests).
PlainOwner plainOwner(
  String text, {
  required Version? version,
  StartTimer? startTimer,
}) =>
    MachineOwner<
      PlainMessage,
      PlainInput,
      PlainTimerFired,
      PlainState,
      EditorBook<String>,
      PlainNotice,
      PlainSaveTimer
    >(plainMachine(text, version: version), startTimer: startTimer);

/// The plain editor machine of a document holding [text], read as
/// [version] (`null` for a new document).
PlainMachine plainMachine(String text, {required Version? version}) => Machine(
  state: PlainState(text, revision: 0),
  work: EditorBook(lineage: version),
  step: plainStep,
);
