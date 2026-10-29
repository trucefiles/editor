import 'package:truce_core/truce_core.dart';

/// Where an open document's edits are, as its save icon shows.
enum SaveState {
  /// Nothing to show: a new document with nothing to keep, or one that
  /// takes no more edits.
  none,

  /// Being edited: the latest edits are only in memory.
  editing,

  /// Kept on this device; not in the folder yet.
  onDevice,

  /// In the document's file in the folder.
  inFolder,
}

/// The [SaveState] of a document whose file stands at [status]; [unsent]:
/// the editor holds edits not yet sent to be kept.
SaveState saveStateOf(FileStatus status, {required bool unsent}) =>
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
