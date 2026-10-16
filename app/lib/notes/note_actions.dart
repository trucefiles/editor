import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_selection.dart';
import '../folders/note_folder.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
import 'note.dart';
import 'note_files.dart';
import 'note_view.dart';
import 'note_views_controller.dart';

final noteActionsProvider = Provider<NoteActions>(NoteActions.new);

/// The user's actions on notes: create, delete and undo, marks (pin,
/// color, "Done" section).
/// No UI: screens ask the user, then call these and show the result.
///
/// Outlives every screen, so an undo still works after the editor closed.
final class NoteActions {
  NoteActions(this._ref);

  final Ref _ref;

  FolderScansController get _scans => _ref.read(folderScansProvider.notifier);

  NoteViewsController get _views => _ref.read(noteViewsProvider.notifier);

  NoteMarks _marksOf(Note note) =>
      _ref.read(folderServicesProvider(note.folder.location)).marks;

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

  /// Creates a note titled [title] in [folder], inside [subfolder] if
  /// given, remembers [folder] as the next default and rescans, so the grid
  /// shows the note.
  Future<Result<Note, StoreError>> create(
    String title,
    NoteFolder folder, {
    RelPath? subfolder,
  }) async {
    _ref.read(lastUsedFolderIdProvider.notifier).choose(folder.id);
    final created = await _ref
        .read(noteFilesProvider(folder))
        .create(title, subfolder: subfolder);
    if (created is Ok) await _scans.refresh();
    return created;
  }

  /// Deletes [note] with its mark and saved view, keeping them and its
  /// [text] for [undoDelete]. Fails if the file changed since [note] was
  /// read. No rescan: the open editor would take the note as deleted
  /// elsewhere; it rescans as it closes.
  Future<Result<DeletedNote, StoreError>> delete(Note note, String text) async {
    final mark = markOf(note);
    final view = _views.viewOf(note.key);
    final deleted = await _ref
        .read(noteFilesProvider(note.folder))
        .delete(note);
    if (deleted case Err(:final error)) return Err(error);
    // Best effort: the next write of the marks drops it anyway.
    await _marksOf(note).remove(note.path);
    await _views.forget(note.key);
    return Ok((note: note, text: text, mark: mark, view: view));
  }

  /// Writes [deleted] back with its mark and view, and rescans. Never
  /// overwrites a file that was created at its path meanwhile.
  Future<Result<void, StoreError>> undoDelete(DeletedNote deleted) async {
    final DeletedNote(:note, :text, :mark, :view) = deleted;
    final restored = await _ref
        .read(noteFilesProvider(note.folder))
        .restore(note, text);
    if (restored is Ok) {
      if (!mark.isNone) await _marksOf(note).set(note.path, mark);
      if (view != null) await _views.remember(note.key, view);
    }
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
    final saved = await _marksOf(note).set(note.path, mark);
    await _scans.refresh();
    return saved;
  }
}

/// A deleted note with its text, mark and saved view, enough to write it
/// back as it was.
typedef DeletedNote = ({Note note, String text, NoteMark mark, NoteView? view});
