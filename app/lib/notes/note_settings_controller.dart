import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../scan/folder_scans.dart';
import '../storage/app_storage.dart';
import 'kept_note_settings.dart';
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
    AsyncNotifierProvider<
      NoteSettingsController,
      Map<String, KeptNoteSettings>
    >(NoteSettingsController.new);

/// How this device shows each note: last view, pin, "Done" section.
class NoteSettingsController
    extends AsyncNotifier<Map<String, KeptNoteSettings>> {
  final _changes = Pool(1);

  @override
  Future<Map<String, KeptNoteSettings>> build() =>
      ref.watch(noteSettingsStoreProvider).load();

  /// The settings of [note]; the defaults if none or not loaded yet.
  NoteSettings settingsOf(NoteKey note) =>
      state.value?[NoteSettingsStore.storeKey(note)]?.settings ??
      NoteSettings.defaults;

  /// Changes the settings of [note] with [change]. Runs after every earlier
  /// change, so each starts from the settings the one before saved.
  Future<void> edit(
    NoteKey note,
    NoteSettings Function(NoteSettings settings) change,
  ) => _change((all) {
    final key = NoteSettingsStore.storeKey(note);
    final changed = change(all[key]?.settings ?? NoteSettings.defaults);
    if (changed.isDefault) {
      all.remove(key);
    } else {
      all[key] = KeptNoteSettings(changed);
    }
  });

  /// Forgets the settings of [note], e.g. as the user deletes it. As
  /// [edit].
  Future<void> forget(NoteKey note) =>
      _change((all) => all.remove(NoteSettingsStore.storeKey(note)));

  /// Forgets the settings of notes that [scans] did not find where they
  /// could be seen, and of folders that are gone, once they have been
  /// missing for [KeptNoteSettings.grace]; until then, at [now], marks
  /// them missing, and found again once a scan finds them. Settings of
  /// folders that could not be scanned, below subfolders that could not
  /// be read, and of notes whose files could not be read count as found.
  /// As [edit].
  Future<void> prune(FolderScans scans, {required DateTime now}) {
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
    bool seen(String key) => found.contains(key) || unknown.any(key.startsWith);
    return _change((all) {
      final pruned = {
        for (final MapEntry(:key, :value) in all.entries)
          key: ?(seen(key) ? value.found : value.missedAt(now)),
      };
      all
        ..clear()
        ..addAll(pruned);
    });
  }

  /// Applies [apply] to the settings; saves them if it changed any.
  Future<void> _change(
    void Function(Map<String, KeptNoteSettings> all) apply,
  ) => _changes.withResource(() async {
    final before = await future;
    final all = {...before};
    apply(all);
    if (mapEquals(before, all)) return;
    state = AsyncData(all);
    await ref.read(noteSettingsStoreProvider).save(all);
  });
}
