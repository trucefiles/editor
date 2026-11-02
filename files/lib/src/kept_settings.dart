import 'package:truce_core/truce_core.dart';

import 'file_settings.dart';
import 'file_settings_store.dart';
import 'folder_state/folder_contents.dart';
import 'kept_file_settings.dart';
import 'listed_file.dart';

/// The rules on every file's settings this device keeps, by
/// [FileSettingsStore.storeKey]: pure, each gives the settings after one
/// change.
typedef KeptSettings = Map<String, KeptFileSettings>;

/// The settings of [file] in [all]; the defaults if none or not loaded
/// yet.
FileSettings settingsIn(KeptSettings? all, FileKey file) =>
    all?[FileSettingsStore.storeKey(file)]?.settings ?? FileSettings.defaults;

/// [all] with the settings of [file] changed by [change]; settings that
/// are the defaults again are not kept.
KeptSettings editedIn(
  KeptSettings all,
  FileKey file,
  FileSettings Function(FileSettings settings) change,
) {
  final key = FileSettingsStore.storeKey(file);
  final changed = change(all[key]?.settings ?? FileSettings.defaults);
  return {
    for (final entry in all.entries)
      if (entry.key != key) entry.key: entry.value,
    if (!changed.isDefault) key: KeptFileSettings(changed),
  };
}

/// [all] without the settings of [file].
KeptSettings forgottenIn(KeptSettings all, FileKey file) => {
  for (final entry in all.entries)
    if (entry.key != FileSettingsStore.storeKey(file)) entry.key: entry.value,
};

/// [all] after a listing, [contents] (see [FolderContents.observe]), at
/// [now]: settings of files that are gone, and of folders that are gone,
/// are marked missing, and forgotten once missing for
/// [KeptFileSettings.grace]; found again once a listing finds them.
/// Settings of files the listing could not see count as found.
KeptSettings prunedIn(
  KeptSettings all,
  FolderContents contents, {
  required DateTime now,
}) => {
  for (final MapEntry(:key, :value) in all.entries)
    key: ?switch (FileSettingsStore.keyOf(key)) {
      final file? when contents.observe(file) is! Gone => value.found,
      _ => value.missedAt(now),
    },
};
