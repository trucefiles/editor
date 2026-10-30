import 'package:truce_core/truce_core.dart';

import 'document_text.dart';

/// Why a document was not moved.
sealed class MoveFailure {
  const MoveFailure();
}

/// The document is not saved in its file, so it can't move now (the
/// save failed, the file changed elsewhere, or another move waits);
/// nothing changed.
final class MoveNotSaved extends MoveFailure {
  const MoveNotSaved();
}

/// A sync conflict of the document waits to be resolved; nothing changed.
final class MoveBlockedByConflict extends MoveFailure {
  const MoveBlockedByConflict();
}

/// The document could not be written in its new place; nothing changed.
final class MoveNotWritten extends MoveFailure {
  const MoveNotWritten(this.error);

  final StoreError error;
}

/// The document is in its new place as [copy], but its old file could not be
/// removed, so both are there.
final class MoveLeftOriginal extends MoveFailure {
  const MoveLeftOriginal(this.copy, this.error);

  final DocumentText copy;
  final StoreError error;
}
