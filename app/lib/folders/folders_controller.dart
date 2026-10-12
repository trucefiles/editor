import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import 'folder_colors.dart';
import 'folder_settings_store.dart';
import 'note_folder.dart';

final folderSettingsStoreProvider = Provider<FolderSettingsStore>(
  (ref) => FolderSettingsStore(
    File('${ref.watch(appStorageProvider).settingsPath}/folders.json'),
  ),
);

final foldersProvider =
    AsyncNotifierProvider<FoldersController, List<NoteFolder>>(
      FoldersController.new,
    );

/// The folders added on this device; every change is saved right away.
class FoldersController extends AsyncNotifier<List<NoteFolder>> {
  final Random _random = Random.secure();

  FolderSettingsStore get _store => ref.read(folderSettingsStoreProvider);

  @override
  Future<List<NoteFolder>> build() async =>
      switch (await ref.watch(folderSettingsStoreProvider).load()) {
        Ok(:final value) => value,
        Err(:final error) => throw FolderSettingsException(error),
      };

  /// Adds the folder at [path], named after its last segment. Does nothing
  /// if it is already added.
  Future<Result<void, SettingsError>> add(String path) async {
    final folders = await future;
    if (folders.any((folder) => folder.path == path)) return const Ok(null);
    final segments = path.split(Platform.pathSeparator)
      ..removeWhere((s) => s.isEmpty);
    return _save([
      ...folders,
      NoteFolder(
        id: _newId(),
        path: path,
        name: segments.isEmpty ? path : segments.last,
        color: nextFolderColor(folders.map((folder) => folder.color)),
      ),
    ]);
  }

  Future<Result<void, SettingsError>> change(NoteFolder changed) async {
    final folders = await future;
    return _save([
      for (final folder in folders) folder.id == changed.id ? changed : folder,
    ]);
  }

  /// Forgets the folder; its files stay untouched.
  Future<Result<void, SettingsError>> remove(NoteFolder removed) async {
    final folders = await future;
    return _save(folders.where((folder) => folder.id != removed.id).toList());
  }

  Future<Result<void, SettingsError>> _save(List<NoteFolder> folders) async {
    final saved = await _store.save(folders);
    if (saved is Ok) state = AsyncData(folders);
    return saved;
  }

  String _newId() =>
      List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join();
}

/// The saved folder list could not be loaded; shown instead of the notes.
final class FolderSettingsException implements Exception {
  const FolderSettingsException(this.error);

  final SettingsError error;
}
