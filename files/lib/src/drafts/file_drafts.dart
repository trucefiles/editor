import 'dart:io';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';

import 'draft.dart';
import 'draft_format.dart';

/// The drafts of one folder's files, one file each in app storage
/// ([DraftFormat]). Per device and never synced.
final class FileDrafts {
  FileDrafts(this._folder);

  final Directory _folder;

  /// Work on one draft's file runs one at a time.
  final _turns = KeyedTaskQueue<String>();

  /// Whether the user removed the folder: no draft is kept after that.
  var _forgotten = false;

  /// Its own, so older app versions, which read only their own drafts,
  /// leave these alone.
  static const _extension = '.draft';
  static const _temp = '.tmp';

  /// The head of every draft that can be read and was last written before
  /// [before]; others are left in place untouched. Temp files of writes
  /// cut off before then go.
  Future<List<DraftHead>> heads({required DateTime before}) async => [
    for (final head in await _heads(before: before) ?? const <DraftHead?>[])
      ?head,
  ];

  /// The head of every draft; `null` if one can't be read. None before the
  /// first.
  Future<List<DraftHead>?> every() async => switch (await _heads()) {
    final heads? when !heads.contains(null) => heads.nonNulls.toList(),
    _ => null,
  };

  /// The content of the draft [head] names; `null` if it can't be read, or
  /// changed since.
  Future<Uint8List?> content(DraftHead head) => _turns.run(head.id, () async {
    try {
      final bytes = await _file(head.id).readAsBytes();
      return switch (DraftFormat.readHead(head.id, bytes)) {
        (:final contentStart, :final contentEnd, head: _)
            when contentEnd == bytes.length =>
          Uint8List.sublistView(bytes, contentStart),
        _ => null,
      };
    } on FileSystemException {
      return null;
    }
  });

  /// The heads of the drafts last written before [before] (by default
  /// all), each `null` if it can't be read; `null` if they can't be
  /// listed. None before the first.
  Future<List<DraftHead?>?> _heads({DateTime? before}) async {
    final heads = <DraftHead?>[];
    try {
      if (!await _folder.exists()) return heads;
      await for (final entity in _folder.list(followLinks: false)) {
        final name = entity.uri.pathSegments.last;
        if (entity is! File) continue;
        if (name.endsWith(_temp)) {
          final id = name.substring(0, name.length - _temp.length);
          // In the draft's turn: a write still running is no cut off one.
          if (before != null) {
            await _turns.run(id, () => _removeCutOff(entity, before));
          }
          continue;
        }
        if (!name.endsWith(_extension)) continue;
        final id = name.substring(0, name.length - _extension.length);
        switch (await _writtenBefore(entity, before)) {
          case true:
            heads.add(await _turns.run(id, () => _readHead(id)));
          case null:
            heads.add(null);
          case false:
        }
      }
    } on FileSystemException {
      return null;
    }
    return heads;
  }

  /// Removes [temp], a write's temp file, if it was last written before
  /// [before]: that write was cut off.
  Future<void> _removeCutOff(File temp, DateTime before) async {
    if (await _writtenBefore(temp, before) != true) return;
    try {
      await temp.delete();
    } on FileSystemException {
      // Tried again at the next start.
    }
  }

  /// Whether [draft] was last written before [before] (any time if
  /// `null`); `null` if that can't be told, as for a draft not readable.
  Future<bool?> _writtenBefore(File draft, DateTime? before) async {
    if (before == null) return true;
    try {
      return (await draft.lastModified()).isBefore(before);
    } on FileSystemException {
      return null;
    }
  }

  /// The head of the draft [id], reading only its start; `null` if it is
  /// no whole draft.
  Future<DraftHead?> _readHead(String id) async {
    final file = _file(id);
    try {
      final opened = await file.open();
      try {
        final start = await opened.read(DraftFormat.headLimit);
        final length = await opened.length();
        return switch (DraftFormat.readHead(id, start)) {
          (:final head, :final contentEnd, contentStart: _)
              when contentEnd == length =>
            head,
          _ => null,
        };
      } finally {
        await opened.close();
      }
    } on FileSystemException {
      return null;
    }
  }

  /// Writes [draft] over any earlier one with its id, atomically, after
  /// every earlier write of it. Returns `false` if it could not be written,
  /// or the folder is [forget]ten.
  Future<bool> keep(Draft draft) => _turns.run(draft.head.id, () async {
    if (_forgotten) return false;
    final file = _file(draft.head.id);
    final temp = File('${_folder.path}/${draft.head.id}$_temp');
    try {
      await _folder.create(recursive: true);
      await temp.writeAsBytes(DraftFormat.encode(draft), flush: true);
      await temp.rename(file.path);
      return true;
    } on FileSystemException {
      return false;
    }
  });

  /// Deletes the draft [id], once its content is kept elsewhere. A draft
  /// that stays by failure is only tried again later.
  Future<void> remove(String id) => _turns.run(id, () async {
    try {
      await _file(id).delete();
    } on FileSystemException {
      // Already gone, or tried again with the next recovery.
    }
  });

  /// Deletes every draft, unreadable ones too, once the writes already
  /// asked for have ended, as the user removes the folder: no draft is
  /// recovered into it, and none is kept after.
  Future<void> forget() async {
    _forgotten = true;
    await _turns.idle();
    try {
      await _folder.delete(recursive: true);
    } on FileSystemException {
      // None yet, or left unseen in app storage.
    }
  }

  /// How many files have readable drafts.
  Future<int> count() async => (await _heads())?.nonNulls.length ?? 0;

  File _file(String id) => File('${_folder.path}/$id$_extension');
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
