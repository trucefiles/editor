import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/app_storage.dart';
import 'note_draft.dart';

/// The drafts of one folder's notes, one JSON file each in app storage.
/// Per device and never synced.
final class NoteDrafts {
  const NoteDrafts(this._folder);

  final Directory _folder;

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
        if (await _read(id, entity) case final draft?) drafts.add(draft);
      }
    } on FileSystemException {
      // No drafts yet, or none readable.
    }
    return drafts;
  }

  /// Writes [draft] over any earlier one with its id, atomically via a
  /// temp file. Returns `false` if it could not be written.
  Future<bool> keep(NoteDraft draft) async {
    final file = _file(draft.id);
    final temp = File('${file.path}.tmp');
    try {
      await _folder.create(recursive: true);
      await temp.writeAsString(jsonEncode(draft.toJson()), flush: true);
      await temp.rename(file.path);
      return true;
    } on FileSystemException {
      return false;
    }
  }

  /// Deletes the draft [id], once its edits are kept elsewhere. A draft
  /// that stays by failure is only tried again later.
  Future<void> remove(String id) async {
    try {
      await _file(id).delete();
    } on FileSystemException {
      // Already gone, or tried again with the next recovery.
    }
  }

  File _file(String id) => File('${_folder.path}/$id$_extension');

  static Future<NoteDraft?> _read(String id, File file) async {
    try {
      return NoteDraft.fromJson(id, jsonDecode(await file.readAsString()));
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }
}

/// The drafts of the folder with this id.
final noteDraftsProvider = Provider.family<NoteDrafts, String>(
  (ref, folderId) =>
      NoteDrafts(Directory(ref.watch(appStorageProvider).draftsPath(folderId))),
);
