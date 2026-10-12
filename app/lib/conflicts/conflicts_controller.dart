import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';
import '../folders/note_folder.dart';
import '../notes/note.dart';
import '../notes/notes_controller.dart';

/// A pending conflict and the folder it is in.
@immutable
final class FolderConflict {
  const FolderConflict(this.folder, this.conflict);

  final NoteFolder folder;
  final Conflict conflict;

  NoteKey get key => (folderId: folder.id, path: conflict.mainPath);
}

/// All pending conflicts of all folders.
@immutable
final class ConflictsSnapshot {
  const ConflictsSnapshot(this.all);

  final List<FolderConflict> all;

  FolderConflict? forNote(NoteKey key) {
    for (final conflict in all) {
      if (conflict.key == key) return conflict;
    }
    return null;
  }

  int countIn(String folderId) =>
      all.where((conflict) => conflict.folder.id == folderId).length;

  /// Conflicts whose main file is gone, shown as recoverable notes.
  List<FolderConflict> get orphans =>
      all.where((conflict) => conflict.conflict.isOrphaned).toList();
}

final conflictsProvider =
    AsyncNotifierProvider<ConflictsController, ConflictsSnapshot>(
      ConflictsController.new,
    );

/// Scans every folder for conflicts whenever the notes are rescanned.
///
/// On start it also deletes conflict backups older than [backupRetention];
/// failing to do so is harmless and retried on the next start.
class ConflictsController extends AsyncNotifier<ConflictsSnapshot> {
  static const backupRetention = Duration(days: 7);

  List<NoteFolder> _folders = const [];
  Future<ConflictsSnapshot>? _running;

  @override
  Future<ConflictsSnapshot> build() async {
    _folders = await ref.watch(foldersProvider.future);
    ref.listen(notesProvider, (_, next) {
      if (next.hasValue) refresh();
    });
    await _pruneBackups();
    return _scanAll();
  }

  /// Rescans now, e.g. right after a resolution.
  Future<void> refresh() async {
    final snapshot = await _scanAll();
    if (ref.mounted) state = AsyncData(snapshot);
  }

  /// Joins a scan that is already running.
  Future<ConflictsSnapshot> _scanAll() =>
      _running ??= _scanFolders().whenComplete(() => _running = null);

  Future<ConflictsSnapshot> _scanFolders() async {
    final all = <FolderConflict>[];
    for (final folder in _folders) {
      final scanned = await _services(folder).conflicts.scan();
      if (scanned case Ok(value: final conflicts)) {
        all.addAll(
          conflicts.map((conflict) => FolderConflict(folder, conflict)),
        );
      }
    }
    return ConflictsSnapshot(all);
  }

  Future<void> _pruneBackups() async {
    final olderThan = DateTime.now().subtract(backupRetention);
    for (final folder in _folders) {
      await _services(folder).conflicts.pruneBackups(olderThan: olderThan);
    }
  }

  FolderServices _services(NoteFolder folder) =>
      ref.read(folderServicesProvider(folder));
}
