import 'package:truce_core/truce_core.dart';

import '../folders/folder_settings_store.dart';

/// User-facing text for expected failures.
extension StoreErrorText on StoreError {
  String get text => switch (this) {
    StoreError.notFound => 'The file or folder no longer exists.',
    StoreError.alreadyExists => 'A file with that name already exists.',
    StoreError.changedSinceRead => 'The file changed in the meantime.',
    StoreError.accessDenied => 'The app has no access to this folder.',
    StoreError.ioFailure => 'The file could not be read or written.',
  };
}

extension SettingsErrorText on SettingsError {
  String get text => switch (this) {
    SettingsError.unreadable => 'The folder list could not be read.',
    SettingsError.corrupt => 'The saved folder list is damaged.',
    SettingsError.unwritable => 'The folder list could not be saved.',
  };
}
