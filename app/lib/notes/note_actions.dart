import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_selection.dart';
import '../folders/folder_services.dart';
import '../folders/note_folder.dart';
import '../scan/folder_scans_controller.dart';
import 'note.dart';
import 'note_files.dart';

final noteActionsProvider = Provider<NoteActions>(NoteActions.new);

/// The user's actions on notes: create, delete and undo, pin and color.
/// No UI: screens ask the user, then call these and show the result.
///
/// Outlives every screen, so an undo still works after the editor closed.
final class NoteActions {
  NoteActions(this._ref);

  final Ref _ref;

  FolderScansController get _scans => _ref.read(folderScansProvider.notifier);

  /// Where a new note goes unless the user picks another of [folders]:
  /// the folder the grid is filtered to, else the last one used, else the
  /// first. [folders] must not be empty.
  NoteFolder defaultFolder(List<NoteFolder> folders) {
    NoteFolder? byId(String? id) =>
        folders.where((folder) => folder.id == id).firstOrNull;
    return byId(_ref.read(selectedFolderIdProvider)) ??
        byId(_ref.read(lastUsedFolderIdProvider)) ??
        folders.first;
  }

  /// Creates a note titled [title] in [folder], remembers [folder] as the
  /// next default and rescans, so the grid shows the note.
  Future<Result<Note, StoreError>> create(
    String title,
    NoteFolder folder,
  ) async {
    _ref.read(lastUsedFolderIdProvider.notifier).choose(folder.id);
    final created = await _ref.read(noteFilesProvider(folder)).create(title);
    if (created is Ok) await _scans.refresh();
    return created;
  }

  /// Deletes [note], keeping its [text] for [undoDelete]. Fails if the file
  /// changed since [note] was read. No rescan: the open editor would take
  /// the note as deleted elsewhere; it rescans as it closes.
  Future<Result<DeletedNote, StoreError>> delete(Note note, String text) async {
    final deleted = await _ref
        .read(noteFilesProvider(note.folder))
        .delete(note);
    return switch (deleted) {
      Ok() => Ok((note: note, text: text)),
      Err(:final error) => Err(error),
    };
  }

  /// Writes [deleted] back and rescans. Never overwrites a file that was
  /// created at its path meanwhile.
  Future<Result<void, StoreError>> undoDelete(DeletedNote deleted) async {
    final restored = await _ref
        .read(noteFilesProvider(deleted.note.folder))
        .restore(deleted.note, deleted.text);
    await _scans.refresh();
    return switch (restored) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// [note]'s pin and color, as last scanned.
  NoteMark markOf(Note note) =>
      _ref.read(folderScansProvider).value?.markOf(note.key) ?? NoteMark.none;

  /// Saves [mark] for [note] and rescans, so every screen shows it. Writes
  /// nothing if [mark] is already set.
  Future<Result<void, StoreError>> setMark(Note note, NoteMark mark) async {
    if (mark == markOf(note)) return const Ok(null);
    final saved = await _ref
        .read(folderServicesProvider(note.folder.location))
        .marks
        .set(note.path, mark);
    await _scans.refresh();
    return saved;
  }
}

/// A deleted note and its text, enough to write it back.
typedef DeletedNote = ({Note note, String text});
