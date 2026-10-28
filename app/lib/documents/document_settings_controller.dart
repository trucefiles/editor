import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart' show Gone;

import '../folder_state/folder_contents.dart';
import '../settings/setting_controller.dart';
import '../storage/app_storage.dart';
import 'document.dart';
import 'document_settings.dart';
import 'document_settings_store.dart';
import 'kept_document_settings.dart';

final documentSettingsStoreProvider =
    Provider<SettingStore<Map<String, KeptNoteSettings>>>(
      (ref) => DocumentSettingsStore(
        // Named for what it first held: the views.
        File(
          '${ref.watch(appStorageProvider).settingsPath}/file_settings.json',
        ),
      ),
    );

final documentSettingsProvider =
    AsyncNotifierProvider<
      DocumentSettingsController,
      Map<String, KeptNoteSettings>
    >(DocumentSettingsController.new);

/// How this device shows each document: last view, pin, "Done" section.
class DocumentSettingsController
    extends SettingController<Map<String, KeptNoteSettings>> {
  @override
  Provider<SettingStore<Map<String, KeptNoteSettings>>> get store =>
      documentSettingsStoreProvider;

  /// The settings of [document]; the defaults if none or not loaded yet.
  DocumentSettings settingsOf(DocumentKey document) =>
      settingsIn(state.value, document);

  /// Changes the settings of [document] with [change], starting from the
  /// settings the change before left.
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

  /// Forgets the settings of documents that are gone in [contents] (see
  /// [FolderContents.observe]), and of folders that are gone, once they
  /// have been missing for [KeptNoteSettings.grace]; until then, at [now],
  /// marks them missing, and found again once a listing finds them.
  /// Settings of documents that could not be seen count as found. As
  /// [edit].
  Future<void> prune(FolderContents contents, {required DateTime now}) =>
      _change((all) {
        final pruned = {
          for (final MapEntry(:key, :value) in all.entries)
            key: ?switch (DocumentSettingsStore.keyOf(key)) {
              final document? when contents.observe(document) is! Gone =>
                value.found,
              _ => value.missedAt(now),
            },
        };
        all
          ..clear()
          ..addAll(pruned);
      });

  /// Applies [apply] to a copy of the settings (see [change]).
  Future<void> _change(
    void Function(Map<String, KeptNoteSettings> all) apply,
  ) => change((before) {
    final all = {...before};
    apply(all);
    return all;
  });
}

/// The settings of [document] in [all]; the defaults if none or not loaded
/// yet.
DocumentSettings settingsIn(
  Map<String, KeptNoteSettings>? all,
  DocumentKey document,
) =>
    all?[DocumentSettingsStore.storeKey(document)]?.settings ??
    DocumentSettings.defaults;
