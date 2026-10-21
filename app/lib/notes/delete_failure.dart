import 'package:truce_core/truce_core.dart';

/// Why a note was not deleted; nothing changed.
sealed class DeleteFailure {
  const DeleteFailure();
}

/// A sync conflict of the note waits to be resolved: deleting the note
/// would leave its other version looking deleted elsewhere.
final class DeleteBlockedByConflict extends DeleteFailure {
  const DeleteBlockedByConflict();
}

/// The note's file could not be deleted.
final class DeleteNotDone extends DeleteFailure {
  const DeleteNotDone(this.error);

  final StoreError error;
}
