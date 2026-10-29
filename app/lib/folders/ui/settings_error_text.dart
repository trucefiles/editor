import 'package:truce_folders/truce_folders.dart';

/// User-facing text for failures of the saved folder list.
extension SettingsErrorText on SettingsError {
  String get text => switch (this) {
    SettingsError.unreadable => 'The folder list could not be read.',
    SettingsError.corrupt => 'The saved folder list is damaged.',
    SettingsError.unwritable => 'The folder list could not be saved.',
  };
}
