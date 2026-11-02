import 'package:truce_core/truce_core.dart';

import 'file_text.dart';

/// Why a file was not moved.
sealed class MoveFailure {
  const MoveFailure();
}

/// The file is not saved in its file, so it can't move now (the
/// save failed, the file changed elsewhere, or another move waits);
/// nothing changed.
final class MoveNotSaved extends MoveFailure {
  const MoveNotSaved();
}

/// A sync conflict of the file waits to be resolved; nothing changed.
final class MoveBlockedByConflict extends MoveFailure {
  const MoveBlockedByConflict();
}

/// The file could not be written in its new place; nothing changed.
final class MoveNotWritten extends MoveFailure {
  const MoveNotWritten(this.error);

  final StoreError error;
}

/// The file is in its new place as [copy], but its old file could not be
/// removed, so both are there.
final class MoveLeftOriginal extends MoveFailure {
  const MoveLeftOriginal(this.copy, this.error);

  final FileText copy;
  final StoreError error;
}
