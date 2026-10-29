import 'dart:io';

import 'package:truce_core/truce_core.dart';

import 'document_draft.dart';

/// The drafts of one base folder's documents, one JSON file each in app
/// storage. Per device and never synced.
final class DocumentDrafts {
  DocumentDrafts(this._folder);

  final Directory _folder;

  /// Work on one draft's file runs one at a time.
  final _turns = KeyedTaskQueue<String>();

  static const _extension = '.json';

  /// Every draft that can be read and was last written before [before];
  /// others are left in place untouched.
  Future<List<DocumentDraft>> all({required DateTime before}) async {
    final drafts = <DocumentDraft>[];
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
  Future<bool> keep(DocumentDraft draft) async => await _turns.run(
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

  /// Deletes the drafts of the documents [under] covers, as the user
  /// removes the folder that showed them: no edit is recovered into it.
  /// With the whole base folder, every draft goes, also unreadable ones.
  Future<void> removeUnder(Selection under) async {
    if (under is WholeFolder) {
      try {
        await _folder.delete(recursive: true);
      } on FileSystemException {
        // None yet, or tried again when the folder is removed again.
      }
      return;
    }
    for (final draft in await all(before: DateTime(9999))) {
      if (under.covers(draft.path)) await remove(draft.id);
    }
  }

  /// How many documents [under] covers have readable drafts.
  Future<int> countUnder(Selection under) async => [
    for (final draft in await all(before: DateTime(9999)))
      if (under.covers(draft.path)) draft,
  ].length;

  File _file(String id) => File('${_folder.path}/$id$_extension');

  Future<DocumentDraft?> _read(String id) async =>
      switch (await _turns.run(id, () => readJson(_file(id)))) {
        Ok(:final value) => DocumentDraft.fromJson(id, value),
        Err() => null,
      };
}

/// The drafts of every base folder, one [DocumentDrafts] each, so the
/// work on each draft's file runs one at a time.
final class DraftsByBase {
  /// The drafts of a base folder are in the folder [folderOf] tells by its
  /// id.
  DraftsByBase(this._folderOf);

  final String Function(String baseId) _folderOf;
  final _byBase = <String, DocumentDrafts>{};

  /// The drafts of the base folder with the id [baseId].
  DocumentDrafts of(String baseId) => _byBase.putIfAbsent(
    baseId,
    () => DocumentDrafts(Directory(_folderOf(baseId))),
  );
}
