import '../add_folder_error.dart';

/// User-facing text for a folder that could not be added.
extension AddFolderErrorText on AddFolderError {
  String get text => switch (this) {
    AddFolderError.unsupportedLocation =>
      'Please pick a folder on the device storage.',
    AddFolderError.overlaps =>
      'This folder overlaps with one you already added.',
    AddFolderError.syncToolInternal =>
      "This folder holds the sync tool's own files, such as old versions. "
          'Please pick the folder with your notes.',
    AddFolderError.notSaved => 'The folder list could not be saved.',
  };
}
