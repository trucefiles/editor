import '../folder_actions.dart';

/// User-facing text for a folder that could not be added.
extension AddFolderErrorText on AddFolderError {
  String get text => switch (this) {
    AddFolderError.unsupportedLocation =>
      'Please pick a folder on the device storage.',
    AddFolderError.notSaved => 'The folder list could not be saved.',
  };
}
