import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';

import '../scan/folder_scans.dart';
import '../storage/app_storage.dart';
import 'document.dart';
import 'document_settings.dart';
import 'document_settings_store.dart';
import 'kept_document_settings.dart';

final documentSettingsStoreProvider = Provider<DocumentSettingsStore>(
  (ref) => DocumentSettingsStore(
    // Named for what it first held: the views.
    File('${ref.watch(appStorageProvider).settingsPath}/note_views.json'),
  ),
);

final documentSettingsProvider =
    AsyncNotifierProvider<
      DocumentSettingsController,
      Map<String, KeptNoteSettings>
    >(DocumentSettingsController.new);

/// How this device shows each document: last view, pin, "Done" section.
class DocumentSettingsController
    extends AsyncNotifier<Map<String, KeptNoteSettings>> {
  final _changes = Pool(1);

  @override
  Future<Map<String, KeptNoteSettings>> build() =>
      ref.watch(documentSettingsStoreProvider).load();

  /// The settings of [document]; the defaults if none or not loaded yet.
  DocumentSettings settingsOf(DocumentKey document) =>
      state.value?[DocumentSettingsStore.storeKey(document)]?.settings ??
      DocumentSettings.defaults;

  /// Changes the settings of [document] with [change]. Runs after every earlier
  /// change, so each starts from the settings the one before saved.
  Future<void> edit(
    DocumentKey document,
    DocumentSettings Function(DocumentSettings settings) change,
  ) => _change((all) {
    final key = DocumentSettingsStore.storeKey(document);
    final changed = change(all[key]?.settings ?? DocumentSettings.defaults);
    if (changed.isDefault) {
      all.remove(key);
    } else {
      all[key] = KeptNoteSettings(changed);
    }
  });

  /// Forgets the settings of [document], e.g. as the user deletes it. As
  /// [edit].
  Future<void> forget(DocumentKey document) =>
      _change((all) => all.remove(DocumentSettingsStore.storeKey(document)));

  /// Forgets the settings of documents that [scans] did not find where they
  /// could be seen, and of folders that are gone, once they have been
  /// missing for [KeptNoteSettings.grace]; until then, at [now], marks
  /// them missing, and found again once a scan finds them. Settings of
  /// folders that could not be scanned, below subfolders that could not
  /// be read, and of documents whose files could not be read count as found.
  /// As [edit].
  Future<void> prune(FolderScans scans, {required DateTime now}) {
    final found = {
      for (final document in scans.documents)
        DocumentSettingsStore.storeKey(document.key),
      for (final key in scans.unreadNotes) DocumentSettingsStore.storeKey(key),
    };
    final unknown = [
      for (final folder in scans.failedFolders.keys)
        DocumentSettingsStore.folderPrefix(folder.id),
      for (final MapEntry(key: folderId, value: subfolders)
          in scans.unreadable.entries)
        for (final subfolder in subfolders)
          '${DocumentSettingsStore.storeKey((folderId: folderId, path: subfolder))}/',
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
    await ref.read(documentSettingsStoreProvider).save(all);
  });
}
