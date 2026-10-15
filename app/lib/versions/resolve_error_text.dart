import 'package:truce_core/truce_core.dart';

/// User-facing text for why keeping a version failed.
extension ResolveErrorText on ResolveError {
  String get text => switch (this) {
    ResolveError.changedSinceScan =>
      'The files changed in the meantime. Please check again.',
    ResolveError.backupFailed => 'No backup could be made, so nothing changed.',
    ResolveError.accessDenied => 'The app has no access to this folder.',
    ResolveError.ioFailure => 'The files could not be written.',
  };
}
