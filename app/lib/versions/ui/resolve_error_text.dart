import 'package:truce_core/truce_core.dart';

/// User-facing text for why keeping a version failed.
extension ResolveErrorText on ResolveError {
  String get text => switch (this) {
    ResolveError.changedSinceScan =>
      'The files changed in the meantime. Please check again.',
    ResolveError.folderMissing =>
      "The folder can't be found. Is it on a drive that isn't connected?",
    ResolveError.backupFailed => "Couldn't make a backup, so nothing changed.",
    ResolveError.accessDenied => 'The app has no access to this folder.',
    ResolveError.ioFailure => "Couldn't write the files.",
    ResolveError.outside => "The app doesn't show these files.",
    ResolveError.folderRemoved => 'The folder was removed from the app.',
  };
}
