import '../add_folder_error.dart';

/// User-facing text for a folder that could not be added.
extension AddFolderErrorText on AddFolderError {
  String get text => switch (this) {
    AddFolderError.unsupportedLocation =>
      'Please pick a folder on the device storage.',
    AddFolderError.overlaps =>
      'This folder is inside, or contains, a folder already added.',
    AddFolderError.notSaved => 'The folder list could not be saved.',
  };
}
