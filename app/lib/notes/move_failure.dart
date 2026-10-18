import 'package:truce_core/truce_core.dart';

import 'note.dart';

/// Why a note was not moved.
sealed class MoveFailure {
  const MoveFailure();
}

/// A sync conflict of the note waits to be resolved; nothing changed.
final class MoveBlockedByConflict extends MoveFailure {
  const MoveBlockedByConflict();
}

/// The note could not be written in its new place; nothing changed.
final class MoveNotWritten extends MoveFailure {
  const MoveNotWritten(this.error);

  final StoreError error;
}

/// The note is in its new place as [copy], but its old file could not be
/// removed, so both are there.
final class MoveLeftOriginal extends MoveFailure {
  const MoveLeftOriginal(this.copy, this.error);

  final Note copy;
  final StoreError error;
}
