import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../scan/folder_scans.dart';
import '../storage/app_storage.dart';
import 'note.dart';
import 'note_settings.dart';
import 'note_settings_store.dart';

final noteSettingsStoreProvider = Provider<NoteSettingsStore>(
  (ref) => NoteSettingsStore(
    // Named for what it first held: the views.
    File('${ref.watch(appStorageProvider).settingsPath}/note_views.json'),
  ),
);

final noteSettingsProvider =
    AsyncNotifierProvider<NoteSettingsController, Map<String, NoteSettings>>(
      NoteSettingsController.new,
    );

/// How this device shows each note: last view, pin, "Done" section.
class NoteSettingsController extends AsyncNotifier<Map<String, NoteSettings>> {
  final _changes = Pool(1);

  @override
  Future<Map<String, NoteSettings>> build() =>
      ref.watch(noteSettingsStoreProvider).load();

  /// The settings of [note]; the defaults if none or not loaded yet.
  NoteSettings settingsOf(NoteKey note) =>
      state.value?[NoteSettingsStore.storeKey(note)] ?? NoteSettings.defaults;

  /// Changes the settings of [note] with [change]. Runs after every earlier
  /// change, so each starts from the settings the one before saved.
  Future<void> edit(
    NoteKey note,
    NoteSettings Function(NoteSettings settings) change,
  ) => _change((all) {
    final key = NoteSettingsStore.storeKey(note);
    final changed = change(all[key] ?? NoteSettings.defaults);
    if (changed.isDefault) {
      all.remove(key);
    } else {
      all[key] = changed;
    }
  });

  /// Forgets the settings of [note], e.g. as the user deletes it. As
  /// [edit].
  Future<void> forget(NoteKey note) =>
      _change((all) => all.remove(NoteSettingsStore.storeKey(note)));

  /// Forgets the settings of notes that [scans] did not find where they
  /// could be seen, and of folders that are gone. Keeps those of folders
  /// that could not be scanned, below subfolders that could not be read,
  /// and of notes whose files could not be read. As [edit].
  Future<void> prune(FolderScans scans) {
    final found = {
      for (final note in scans.notes) NoteSettingsStore.storeKey(note.key),
      for (final key in scans.unreadNotes) NoteSettingsStore.storeKey(key),
    };
    final unknown = [
      for (final folder in scans.failedFolders.keys)
        NoteSettingsStore.folderPrefix(folder.id),
      for (final MapEntry(key: folderId, value: subfolders)
          in scans.unreadable.entries)
        for (final subfolder in subfolders)
          '${NoteSettingsStore.storeKey((folderId: folderId, path: subfolder))}/',
    ];
    return _change(
      (all) => all.removeWhere(
        (key, _) => !found.contains(key) && !unknown.any(key.startsWith),
      ),
    );
  }

  /// Applies [apply] to the settings; saves them if it changed any.
  Future<void> _change(void Function(Map<String, NoteSettings> all) apply) =>
      _changes.withResource(() async {
        final before = await future;
        final all = {...before};
        apply(all);
        if (mapEquals(before, all)) return;
        state = AsyncData(all);
        await ref.read(noteSettingsStoreProvider).save(all);
      });
}
