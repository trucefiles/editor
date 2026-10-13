import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_services.dart';
import '../folders/folders_controller.dart';
import '../folders/note_folder.dart';
import 'note.dart';
import 'note_scanner.dart';

/// All notes of all folders, plus the folders that could not be read.
@immutable
final class NotesSnapshot {
  const NotesSnapshot({
    required this.notes,
    required this.failedFolders,
    required this.startedAt,
  });

  /// Newest first.
  final List<Note> notes;

  final Map<NoteFolder, StoreError> failedFolders;

  /// When the scan began; files written later may show older versions.
  final DateTime startedAt;

  Note? find(NoteKey key) {
    for (final note in notes) {
      if (note.key == key) return note;
    }
    return null;
  }
}

final notesProvider = AsyncNotifierProvider<NotesController, NotesSnapshot>(
  NotesController.new,
);

/// Scans every folder, and rescans every [pollInterval] so changes from
/// the sync tool or other editors show up without a restart.
class NotesController extends AsyncNotifier<NotesSnapshot> {
  static const pollInterval = Duration(seconds: 5);

  final Map<String, NoteScanner> _scanners = {};
  List<NoteFolder> _folders = const [];
  Future<NotesSnapshot>? _running;

  @override
  Future<NotesSnapshot> build() async {
    _folders = await ref.watch(foldersProvider.future);
    _scanners.removeWhere(
      (id, _) => !_folders.any((folder) => folder.id == id),
    );
    final timer = Timer.periodic(pollInterval, (_) => refresh());
    ref.onDispose(timer.cancel);
    return _scanAll();
  }

  /// Rescans now, e.g. after a write or when the app comes back to the
  /// foreground. Joins a scan that is already running.
  /// Does nothing once this controller is disposed.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final snapshot = await _scanAll();
    if (ref.mounted) state = AsyncData(snapshot);
  }

  Future<NotesSnapshot> _scanAll() =>
      _running ??= _scanFolders().whenComplete(() => _running = null);

  Future<NotesSnapshot> _scanFolders() async {
    final startedAt = DateTime.now();
    final notes = <Note>[];
    final failed = <NoteFolder, StoreError>{};
    for (final folder in _folders) {
      switch (await _scannerFor(folder).scan()) {
        case Ok(:final value):
          notes.addAll(value);
        case Err(:final error):
          failed[folder] = error;
      }
    }
    notes.sort((a, b) => b.stamp.modified.compareTo(a.stamp.modified));
    return NotesSnapshot(
      notes: notes,
      failedFolders: failed,
      startedAt: startedAt,
    );
  }

  /// A folder whose name or color changed gets a new scanner, so its notes
  /// carry the new settings.
  NoteScanner _scannerFor(NoteFolder folder) {
    final services = ref.read(folderServicesProvider(folder));
    final existing = _scanners[folder.id];
    if (existing != null && existing.folder == folder) return existing;
    return _scanners[folder.id] = NoteScanner(folder, services);
  }
}
