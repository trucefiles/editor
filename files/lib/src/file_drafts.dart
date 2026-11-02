import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'file_draft.dart';

/// The drafts of one folder's files, one JSON file each in app
/// storage. Per device and never synced.
final class FileDrafts {
  FileDrafts(this._folder);

  final Directory _folder;

  /// Work on one draft's file runs one at a time.
  final _turns = KeyedTaskQueue<String>();

  static const _extension = '.json';

  /// Every draft that can be read and was last written before [before];
  /// others are left in place untouched.
  Future<List<FileDraft>> all({required DateTime before}) async {
    final drafts = <FileDraft>[];
    try {
      await for (final entity in _folder.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is! File || !name.endsWith(_extension)) continue;
        if (!(await entity.lastModified()).isBefore(before)) continue;
        final id = name.substring(0, name.length - _extension.length);
        if (await _read(id) case final draft?) drafts.add(draft);
      }
    } on FileSystemException {
      // No drafts yet, or none readable.
    }
    return drafts;
  }

  /// Writes [draft] over any earlier one with its id, atomically, after
  /// every earlier write of it. Returns `false` if it could not be written.
  Future<bool> keep(FileDraft draft) async => await _turns.run(
    draft.id,
    () => writeJsonAtomically(_file(draft.id), draft.toJson()),
  ) is Ok;

  /// Deletes the draft [id], once its edits are kept elsewhere. A draft
  /// that stays by failure is only tried again later.
  Future<void> remove(String id) => _turns.run(id, () async {
    try {
      await _file(id).delete();
    } on FileSystemException {
      // Already gone, or tried again with the next recovery.
    }
  });

  /// Deletes every draft, unreadable ones too, as the user removes the
  /// folder: no edit is recovered into it.
  Future<void> removeAll() async {
    try {
      await _folder.delete(recursive: true);
    } on FileSystemException {
      // None yet, or tried again when the folder is removed again.
    }
  }

  /// How many files have readable drafts.
  Future<int> count() async => (await all(before: DateTime(9999))).length;

  File _file(String id) => File('${_folder.path}/$id$_extension');

  Future<FileDraft?> _read(String id) async =>
      switch (await _turns.run(id, () => readJson(_file(id)))) {
        Ok(:final value) => FileDraft.fromJson(id, value),
        Err() => null,
      };
}

/// The drafts of every folder, one [FileDrafts] each, so the work on
/// each draft's file runs one at a time.
final class DraftsByFolder {
  /// The drafts of a folder are in the app storage folder [pathOf] tells.
  DraftsByFolder(this._pathOf);

  final String Function(FolderId folder) _pathOf;
  final _byFolder = <FolderId, FileDrafts>{};

  /// The drafts of [folder].
  FileDrafts of(FolderId folder) => _byFolder.putIfAbsent(
    folder,
    () => FileDrafts(Directory(_pathOf(folder))),
  );
}
