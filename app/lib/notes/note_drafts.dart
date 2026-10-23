import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../storage/app_storage.dart';
import '../storage/json_file.dart';
import 'note_draft.dart';

/// The drafts of one folder's notes, one JSON file each in app storage.
/// Per device and never synced.
final class NoteDrafts {
  NoteDrafts(this._folder);

  final Directory _folder;

  /// Work on one draft's file runs one at a time.
  final _turns = KeyedTaskQueue<String>();

  static const _extension = '.json';

  /// Every draft that can be read and was last written before [before];
  /// others are left in place untouched.
  Future<List<NoteDraft>> all({required DateTime before}) async {
    final drafts = <NoteDraft>[];
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
  Future<bool> keep(NoteDraft draft) async => await _turns.run(
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

  /// Deletes every draft, once their folder is removed from the app.
  Future<void> clear() async {
    try {
      await _folder.delete(recursive: true);
    } on FileSystemException {
      // None yet, or tried again when the folder is removed again.
    }
  }

  File _file(String id) => File('${_folder.path}/$id$_extension');

  Future<NoteDraft?> _read(String id) async =>
      switch (await _turns.run(id, () => readJson(_file(id)))) {
        Ok(:final value) => NoteDraft.fromJson(id, value),
        Err() => null,
      };
}

/// The drafts of the folder with this id.
final noteDraftsProvider = Provider.family<NoteDrafts, String>(
  (ref, folderId) =>
      NoteDrafts(Directory(ref.watch(appStorageProvider).draftsPath(folderId))),
);
