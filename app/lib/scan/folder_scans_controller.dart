import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

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
  Future<FolderScans>? _running;

  @override
  Future<FolderScans> build() async {
    _folders = await ref.watch(foldersProvider.future);
    final timer = Timer.periodic(pollInterval, (_) => refresh());
    ref.onDispose(timer.cancel);
    return _scanAll();
  }

  /// Rescans now, e.g. after a write or when the app comes back to the
  /// foreground. Joins a scan that is already running.
  /// Does nothing once this controller is disposed.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final scans = await _scanAll();
    if (ref.mounted) state = AsyncData(scans);
  }

  Future<FolderScans> _scanAll() =>
      _running ??= _scanFolders().whenComplete(() => _running = null);

  Future<FolderScans> _scanFolders() async {
    final startedAt = DateTime.now();
    final notes = <Note>[];
    final conflicts = <FolderConflict>[];
    final failed = <NoteFolder, StoreError>{};
    for (final folder in _folders) {
      final services = ref.read(folderServicesProvider(folder));
      switch (await services.scanner.scan()) {
        case Ok(value: final scan):
          notes.addAll(await _loaderFor(folder, services).load(scan.files));
          conflicts.addAll(
            scan.conflicts.map((conflict) => FolderConflict(folder, conflict)),
          );
        case Err(:final error):
          failed[folder] = error;
      }
    }
    notes.sort((a, b) => b.modified.compareTo(a.modified));
    return FolderScans(
      notes: notes,
      conflicts: FolderConflicts(conflicts),
      failedFolders: failed,
      startedAt: startedAt,
    );
  }

  NoteLoader _loaderFor(NoteFolder folder, FolderServices services) =>
      _loaders.putIfAbsent(folder.id, () => NoteLoader(folder, services));
}
