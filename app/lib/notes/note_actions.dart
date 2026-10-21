import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/folder_selection.dart';
import '../folders/note_folder.dart';
import '../reach/folder_reach_controller.dart';
import '../scan/folder_scans_controller.dart';
import '../sync_tool/folder_services.dart';
import 'delete_failure.dart';
import 'move_failure.dart';
import 'new_note_place/new_note_place.dart';
import 'new_note_place/new_note_place_controller.dart';
import 'note.dart';
import 'note_files.dart';
import 'note_place.dart';
import 'note_settings.dart';
import 'note_settings_controller.dart';

final noteActionsProvider = Provider<NoteActions>(NoteActions.new);

/// The user's actions on notes: create, move or rename, delete and undo,
/// color.
/// No UI: screens ask the user, then call these and show the result.
///
/// Outlives every screen, so an undo still works after the editor closed.
final class NoteActions {
  NoteActions(this._ref);

  final Ref _ref;

  FolderScansController get _scans => _ref.read(folderScansProvider.notifier);

  NoteSettingsController get _settings =>
      _ref.read(noteSettingsProvider.notifier);

  NoteMarks _marksOf(Note note) =>
      _ref.read(folderServicesProvider(note.folder.location)).marks;

  /// Where a new note goes without a place set for new notes: the one of
  /// [folders] the grid is filtered to, else the first. [folders] must not
  /// be empty.
  NoteFolder defaultFolder(List<NoteFolder> folders) {
    final selected = _ref.read(selectedFolderIdProvider);
    return folders.where((folder) => folder.id == selected).firstOrNull ??
        folders.first;
  }

  /// Those of [folders] that new notes can go into: the ones that can be
  /// reached.
  List<NoteFolder> reachableOf(List<NoteFolder> folders) => [
    for (final folder in folders)
      if (_ref.read(folderReachProvider(folder.location)) != Reach.unreachable)
        folder,
  ];

  /// Where a new note goes: the place the user set for new notes, if its
  /// folder is one of [folders], else the [defaultFolder] of [folders].
  NotePlace newNotePlace(List<NoteFolder> folders) =>
      resolveNewNotePlace(_ref.read(newNotePlaceProvider).value, folders) ??
      (folder: defaultFolder(folders), subfolder: null);

  /// The subfolders of [folder], as last scanned.
  List<RelPath> subfoldersOf(NoteFolder folder) =>
      _ref.read(folderScansProvider).value?.subfoldersOf(folder.id) ?? const [];

  /// Creates a note holding [text] at [place], named after [title], and
  /// rescans, so the grid shows the note.
  Future<Result<Note, StoreError>> create(
    NotePlace place, {
    required String title,
    required String text,
  }) async {
    final created = await _ref
        .read(noteFilesProvider(place.folder))
        .create(title, subfolder: place.subfolder, text: text);
    if (created is Ok) await _scans.refresh();
    return created;
  }

  /// Moves [note], holding [text], to [place], renamed after [title] if
  /// given: writes it there under that name (with a number if taken), in
  /// its byte style, with its color and settings, then removes the old
  /// file. Refused while a sync conflict of
  /// the note waits. If the old file can't be removed, e.g. as it changed
  /// since [note] was read, both stay: never lose data. No rescan, as for
  /// [delete].
  Future<Result<Note, MoveFailure>> move(
    Note note,
    String text,
    NotePlace place, {
    String? title,
  }) async {
    if (_conflictWaits(note)) return const Err(MoveBlockedByConflict());
    final mark = markOf(note);
    final settings = _settings.settingsOf(note.key);
    final copied = await _ref
        .read(noteFilesProvider(place.folder))
        .copyIn(note, text, subfolder: place.subfolder, title: title);
    final Note copy;
    switch (copied) {
      case Ok(:final value):
        copy = value;
      case Err(:final error):
        return Err(MoveNotWritten(error));
    }
    // Best effort, as the color of a new note.
    if (mark != NoteMark.none) await _marksOf(copy).set(copy.path, mark);
    await _settings.edit(copy.key, (_) => settings);
    final deleted = await _ref
        .read(noteFilesProvider(note.folder))
        .delete(note);
    if (deleted case Err(:final error)) {
      return Err(MoveLeftOriginal(copy, error));
    }
    await _marksOf(note).remove(note.path);
    await _settings.forget(note.key);
    return Ok(copy);
  }

  /// Deletes [note] with its mark and settings, keeping them and its
  /// [text] for [undoDelete]. Refused while a sync conflict of the note
  /// waits. Fails if the file changed since [note] was read. No rescan:
  /// the open editor would take the note as deleted elsewhere; it rescans
  /// as it closes.
  Future<Result<DeletedNote, DeleteFailure>> delete(
    Note note,
    String text,
  ) async {
    if (_conflictWaits(note)) return const Err(DeleteBlockedByConflict());
    final mark = markOf(note);
    final settings = _settings.settingsOf(note.key);
    final deleted = await _ref
        .read(noteFilesProvider(note.folder))
        .delete(note);
    if (deleted case Err(:final error)) return Err(DeleteNotDone(error));
    // Best effort: the next write of the marks drops it anyway.
    await _marksOf(note).remove(note.path);
    await _settings.forget(note.key);
    return Ok((note: note, text: text, mark: mark, settings: settings));
  }

  /// Writes [deleted] back with its mark and settings, and rescans. Never
  /// overwrites a file that was created at its path meanwhile.
  Future<Result<void, StoreError>> undoDelete(DeletedNote deleted) async {
    final DeletedNote(:note, :text, :mark, :settings) = deleted;
    final restored = await _ref
        .read(noteFilesProvider(note.folder))
        .restore(note, text);
    if (restored is Ok) {
      // Even no mark: else an older mark from another device would win.
      await _marksOf(note).set(note.path, mark);
      await _settings.edit(note.key, (_) => settings);
    }
    await _scans.refresh();
    return switch (restored) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// Whether a sync conflict of [note] waits, as last scanned.
  bool _conflictWaits(Note note) =>
      _ref.read(folderScansProvider).value?.conflicts.forNote(note.key) != null;

  /// [note]'s color, as last scanned.
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

/// A deleted note with its text, mark and settings, enough to write it
/// back as it was.
typedef DeletedNote = ({
  Note note,
  String text,
  NoteMark mark,
  NoteSettings settings,
});
