import 'package:truce_folders/truce_folders.dart';

/// User-facing text for a change to the folder list that did not happen.
extension FolderErrorText on FolderError {
  String get text => switch (this) {
    FolderError.overlaps =>
      "This overlaps a folder that's already in the app. A file "
          'can only belong to one folder.',
    FolderError.notSaved =>
      "Couldn't save the folder list, so nothing changed.",
  };
}
