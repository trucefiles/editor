import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart' show SettingStore;
import 'package:truce_files/truce_files.dart';

import '../settings/setting_controller.dart';
import '../storage/app_storage.dart';

final fileSettingsStoreProvider = Provider<SettingStore<KeptSettings>>(
  (ref) => FileSettingsStore(
    // Named for what it first held: the views.
    File('${ref.watch(appStorageProvider).settingsPath}/file_settings.json'),
  ),
);

final fileSettingsProvider =
    AsyncNotifierProvider<FileSettingsController, KeptSettings>(
      FileSettingsController.new,
    );

/// How this device shows each file: last view, pin, "Done" section.
class FileSettingsController extends SettingController<KeptSettings>
    implements FileSettingsKeeper {
  @override
  Provider<SettingStore<KeptSettings>> get store => fileSettingsStoreProvider;

  @override
  FileSettings settingsOf(FileKey file) => settingsIn(state.value, file);

  @override
  Future<void> edit(
    FileKey file,
    FileSettings Function(FileSettings settings) change,
  ) => this.change((all) => editedIn(all, file, change));

  @override
  Future<void> forget(FileKey file) => change((all) => forgottenIn(all, file));

  /// Prunes the settings by a listing, [contents], at [now] (see
  /// [prunedIn]).
  Future<void> prune(FolderContents contents, {required DateTime now}) =>
      change((all) => prunedIn(all, contents, now: now));
}
