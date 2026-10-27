import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pool/pool.dart';
import 'package:truce_core/truce_core.dart' show Gone;

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

  /// Forgets the settings of documents that [scans] found gone (see
  /// [FolderScans.observe]), and of folders that are gone, once they have
  /// been missing for [KeptNoteSettings.grace]; until then, at [now],
  /// marks them missing, and found again once a scan finds them. Settings
  /// of documents the scan could not see count as found. As [edit].
  Future<void> prune(FolderScans scans, {required DateTime now}) => _change((
    all,
  ) {
    final pruned = {
      for (final MapEntry(:key, :value) in all.entries)
        key: ?switch (DocumentSettingsStore.keyOf(key)) {
          final document? when scans.observe(document) is! Gone => value.found,
          _ => value.missedAt(now),
        },
    };
    all
      ..clear()
      ..addAll(pruned);
  });

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
