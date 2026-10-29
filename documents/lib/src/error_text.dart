import 'package:truce_core/truce_core.dart';

/// User-facing text for expected storage failures.
extension StoreErrorText on StoreError {
  String get text => switch (this) {
    StoreError.notFound => 'The file or folder no longer exists.',
    StoreError.alreadyExists => 'A file with that name already exists.',
    StoreError.changedSinceRead => 'The file changed in the meantime.',
    StoreError.accessDenied => 'The app has no access to this folder.',
    StoreError.ioFailure => 'The file could not be read or written.',
    StoreError.outside => "The app doesn't show this file.",
  };
}
