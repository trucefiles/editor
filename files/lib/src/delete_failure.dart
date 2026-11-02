import 'package:truce_core/truce_core.dart';

/// Why a file was not deleted; nothing changed.
sealed class DeleteFailure {
  const DeleteFailure();
}

/// A sync conflict of the file waits to be resolved: deleting the file
/// would leave its other version looking deleted elsewhere.
final class DeleteBlockedByConflict extends DeleteFailure {
  const DeleteBlockedByConflict();
}

/// The file could not be deleted.
final class DeleteNotDone extends DeleteFailure {
  const DeleteNotDone(this.error);

  final StoreError error;
}
