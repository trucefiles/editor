import 'package:truce_folders/truce_folders.dart';

/// User-facing text for a change to the folder list that did not happen.
extension FolderErrorText on FolderError {
  String get text => switch (this) {
    FolderError.overlaps =>
      'This lies at, inside or around a folder added before. Each file can '
          'be in one folder only.',
    FolderError.notSaved =>
      'The folder list could not be saved, so nothing changed.',
  };
}
