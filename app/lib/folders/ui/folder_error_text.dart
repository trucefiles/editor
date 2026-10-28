import '../folder_error.dart';

/// User-facing text for a change to the folder list that did not happen.
extension FolderErrorText on FolderError {
  String get text => switch (this) {
    FolderError.overlaps =>
      'This overlaps with a folder you already added. Each document can '
          'be in one folder only.',
    FolderError.syncToolInternal =>
      "This folder holds the sync tool's own files, such as old versions. "
          'Please pick the folder with your documents.',
    FolderError.notSaved => 'The folder list could not be saved.',
  };
}
