import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../common/fresh_runs.dart';
import '../conflicts/folder_conflicts.dart';
import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';
import '../folders/note_folder.dart';
import '../notes/note.dart';
import '../notes/note_loader.dart';
import 'folder_scans.dart';

final folderScansProvider =
    AsyncNotifierProvider<FolderScansController, FolderScans>(
      FolderScansController.new,
    );

/// Scans every folder for notes and conflicts, and rescans every
/// [pollInterval] so changes from the sync tool or other editors show up
/// without a restart.
///
/// Riverpod builds a new controller whenever the folders change, so each
/// controller scans one fixed list of folders.
class FolderScansController extends AsyncNotifier<FolderScans> {
  static const pollInterval = Duration(seconds: 5);

  List<NoteFolder> _folders = const [];
  final Map<String, NoteLoader> _loaders = {};
  late final _scans = FreshRuns(_scanFolders);

  @override
  Future<FolderScans> build() async {
    _folders = await ref.watch(foldersProvider.future);
    final timer = Timer.periodic(pollInterval, (_) => refresh());
    ref.onDispose(timer.cancel);
    return _scans.run();
  }

  /// Rescans now, e.g. after a write or when the app comes back to the
  /// foreground. The scan starts after this call, so it sees every write
  /// made before. Does nothing once this controller is disposed.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final scans = await _scans.run();
    if (ref.mounted) state = AsyncData(scans);
  }

  Future<FolderScans> _scanFolders() async {
    final startedAt = DateTime.now();
    final notes = <Note>[];
    final marks = <NoteKey, NoteMark>{};
    final conflicts = <FolderConflict>[];
    final failed = <NoteFolder, StoreError>{};
    for (final folder in _folders) {
      final services = ref.read(folderServicesProvider(folder.location));
      switch (await services.scanner.scan()) {
        case Ok(value: final scan):
          notes.addAll(await _loaderFor(folder, services).load(scan.files));
          marks.addAll(await _marksOf(folder, services));
          conflicts.addAll(
            scan.conflicts.map((conflict) => FolderConflict(folder, conflict)),
          );
        case Err(:final error):
          failed[folder] = error;
      }
    }
    bool pinned(Note note) => marks[note.key]?.pinned ?? false;
    notes.sort(
      (a, b) =>
          pinned(a) != pinned(b) ? (pinned(a) ? -1 : 1) : _newestFirst(a, b),
    );
    return FolderScans(
      notes: notes,
      marks: marks,
      conflicts: FolderConflicts(conflicts),
      failedFolders: failed,
      startedAt: startedAt,
    );
  }

  /// Newest first; notes with the same time by folder and path, so the
  /// order never changes between scans of the same files.
  static int _newestFirst(Note a, Note b) {
    final byTime = b.modified.compareTo(a.modified);
    if (byTime != 0) return byTime;
    final byFolder = a.folder.id.compareTo(b.folder.id);
    return byFolder != 0 ? byFolder : a.path.value.compareTo(b.path.value);
  }

  /// The folder's marks; none if they cannot be read, as they only help.
  Future<Map<NoteKey, NoteMark>> _marksOf(
    NoteFolder folder,
    FolderServices services,
  ) async => switch (await services.marks.load()) {
    Ok(:final value) => {
      for (final MapEntry(key: path, value: mark) in value.entries)
        (folderId: folder.id, path: path): mark,
    },
    Err() => const {},
  };

  NoteLoader _loaderFor(NoteFolder folder, FolderServices services) =>
      _loaders.putIfAbsent(folder.id, () => NoteLoader(folder, services));
}
