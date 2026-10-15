import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../platform/app_storage.dart';
import '../platform/host_paths.dart';
import 'add_folder_error.dart';
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
  /// if it is already added. Refuses a folder inside an added one, or one
  /// holding an added one: their notes would show twice. Compares the
  /// folders' host paths, as a sandbox may show each at its own path.
  Future<Result<void, AddFolderError>> add(String path) async {
    final folders = await future;
    final hostPaths = ref.read(hostPathsProvider);
    final segments = _segments(await hostPaths.of(path));
    final added = [
      for (final folder in folders) _segments(await hostPaths.of(folder.path)),
    ];
    if (added.any((other) => listEquals(other, segments))) {
      return const Ok(null);
    }
    if (added.any(
      (other) => _isWithin(segments, other) || _isWithin(other, segments),
    )) {
      return const Err(AddFolderError.overlaps);
    }
    final saved = await _save([
      ...folders,
      NoteFolder(
        id: _newId(),
        path: path,
        name: _segments(path).lastOrNull ?? path,
        color: nextFolderColor(folders.map((folder) => folder.color)),
      ),
    ]);
    return switch (saved) {
      Ok() => const Ok(null),
      Err() => const Err(AddFolderError.notSaved),
    };
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

  static List<String> _segments(String path) =>
      path.split(Platform.pathSeparator)..removeWhere((s) => s.isEmpty);

  /// Whether the folder at [inner] lies inside the one at [outer].
  static bool _isWithin(List<String> inner, List<String> outer) =>
      inner.length > outer.length &&
      listEquals(inner.sublist(0, outer.length), outer);

  String _newId() =>
      List.generate(12, (_) => _random.nextInt(16).toRadixString(16)).join();
}

/// The saved folder list could not be loaded; shown instead of the notes.
final class FolderSettingsException implements Exception {
  const FolderSettingsException(this.error);

  final SettingsError error;
}
