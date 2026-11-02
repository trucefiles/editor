import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart' show Gone, SettingStore;
import 'package:truce_files/truce_files.dart';

import '../settings/setting_controller.dart';
import '../storage/app_storage.dart';

final fileSettingsStoreProvider =
    Provider<SettingStore<Map<String, KeptFileSettings>>>(
      (ref) => FileSettingsStore(
        // Named for what it first held: the views.
        File(
          '${ref.watch(appStorageProvider).settingsPath}/file_settings.json',
        ),
      ),
    );

final fileSettingsProvider =
    AsyncNotifierProvider<
      FileSettingsController,
      Map<String, KeptFileSettings>
    >(FileSettingsController.new);

/// How this device shows each file: last view, pin, "Done" section.
class FileSettingsController
    extends SettingController<Map<String, KeptFileSettings>>
    implements FileSettingsKeeper {
  @override
  Provider<SettingStore<Map<String, KeptFileSettings>>> get store =>
      fileSettingsStoreProvider;

  @override
  FileSettings settingsOf(FileKey file) => settingsIn(state.value, file);

  @override
  Future<void> edit(
    FileKey file,
    FileSettings Function(FileSettings settings) change,
  ) => _change((all) {
    final key = FileSettingsStore.storeKey(file);
    final changed = change(all[key]?.settings ?? FileSettings.defaults);
    if (changed.isDefault) {
      all.remove(key);
    } else {
      all[key] = KeptFileSettings(changed);
    }
  });

  /// As [edit].
  @override
  Future<void> forget(FileKey file) =>
      _change((all) => all.remove(FileSettingsStore.storeKey(file)));

  /// Forgets the settings of files that are gone in [contents] (see
  /// [FolderContents.observe]), and of folders that are gone, once they
  /// have been missing for [KeptFileSettings.grace]; until then, at [now],
  /// marks them missing, and found again once a listing finds them.
  /// Settings of files that could not be seen count as found. As
  /// [edit].
  Future<void> prune(FolderContents contents, {required DateTime now}) =>
      _change((all) {
        final pruned = {
          for (final MapEntry(:key, :value) in all.entries)
            key: ?switch (FileSettingsStore.keyOf(key)) {
              final file? when contents.observe(file) is! Gone => value.found,
              _ => value.missedAt(now),
            },
        };
        all
          ..clear()
          ..addAll(pruned);
      });

  /// Applies [apply] to a copy of the settings (see [change]).
  Future<void> _change(
    void Function(Map<String, KeptFileSettings> all) apply,
  ) => change((before) {
    final all = {...before};
    apply(all);
    return all;
  });
}

/// The settings of [file] in [all]; the defaults if none or not loaded
/// yet.
FileSettings settingsIn(Map<String, KeptFileSettings>? all, FileKey file) =>
    all?[FileSettingsStore.storeKey(file)]?.settings ?? FileSettings.defaults;
