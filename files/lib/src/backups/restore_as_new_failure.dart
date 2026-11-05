import 'package:truce_core/truce_core.dart';

/// Why a backup was not restored as a new file; nothing was written.
sealed class RestoreAsNewFailure {
  const RestoreAsNewFailure();
}

/// The backup holds no text the app can read.
final class BackupNotText extends RestoreAsNewFailure {
  const BackupNotText();
}

/// The backup could not be read, or its new file not written.
final class NotRestored extends RestoreAsNewFailure {
  const NotRestored(this.error);

  final StoreError error;
}
