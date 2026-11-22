import 'package:truce_files/truce_files.dart';

import '../text_file_owner/text_file_contract.dart';

/// The [SaveState] of a file whose file stands at [status]; [unsent]:
/// the editor holds edits not yet sent to be kept.
SaveState saveStateOf(TextFileStatus status, {required bool unsent}) =>
    switch (status) {
      _ when unsent => SaveState.editing,
      Editing(phase: EditPhase.inMemory) => SaveState.editing,
      Editing() ||
      ChangedElsewhere() ||
      DeletedElsewhere() ||
      SaveFailed() => SaveState.onDevice,
      InStep() => SaveState.inFolder,
      Unwritten() || KeptAsConflict() || Closed() => SaveState.none,
    };
