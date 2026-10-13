import 'dart:convert';
import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';

/// Copies of conflict inputs in app storage, so a resolution can be undone.
///
/// One flat folder; a file per input, named
/// `<time in µs since epoch>.<side>.<main path>`, e.g.
/// `1791818275000000.other.lists%2Ftodo.md`. Only `%` and `/` in the path
/// are escaped (`%25`, `%2F`), so names stay short in any script. A long
/// path keeps only its end.
final class ConflictBackups {
  const ConflictBackups(this._store);

  final FileStore _store;

  /// Saves the inputs of one resolution made [at]. [current] is `null` for
  /// an orphaned conflict.
  Future<Result<void, StoreError>> save({
    required DateTime at,
    required RelPath mainPath,
    required Uint8List? current,
    required Uint8List other,
  }) async {
    if (current != null) {
      final saved = await _save(at, 'current', mainPath, current);
      if (saved is Err) return saved;
    }
    return _save(at, 'other', mainPath, other);
  }

  /// Deletes backups saved before [olderThan]. Stops at the first failure.
  Future<Result<void, StoreError>> prune({required DateTime olderThan}) async {
    final List<FileEntry> entries;
    switch (await _store.list()) {
      case Ok(:final value):
        entries = value;
      case Err(:final error):
        return Err(error);
    }
    for (final entry in entries) {
      final savedAt = _savedAt(entry.path);
      if (savedAt == null || !savedAt.isBefore(olderThan)) continue;
      final deleted = await _store.delete(
        entry.path,
        ifUnchanged: entry.version,
      );
      if (deleted is Err) return deleted;
    }
    return const Ok(null);
  }

  Future<Result<void, StoreError>> _save(
    DateTime at,
    String side,
    RelPath mainPath,
    Uint8List bytes,
  ) async {
    final escaped = mainPath.value
        .replaceAll('%', '%25')
        .replaceAll('/', '%2F');
    final name = '${at.microsecondsSinceEpoch}.$side.${_tail(escaped)}';
    final created = await _store.create(RelPath.parse(name)!, bytes);
    return switch (created) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// File systems allow 255 bytes per name; this leaves room for the time
  /// and side.
  static const _maxPathBytes = 200;

  /// The end of [escaped] that fits [_maxPathBytes] in UTF-8, so the
  /// note's own name stays readable.
  static String _tail(String escaped) {
    final runes = escaped.runes.toList();
    var start = runes.length;
    var bytes = 0;
    while (start > 0) {
      final size = utf8.encode(String.fromCharCode(runes[start - 1])).length;
      if (bytes + size > _maxPathBytes) break;
      bytes += size;
      start--;
    }
    return String.fromCharCodes(runes, start);
  }

  /// When the backup at [path] was saved; `null` if it is not a backup.
  static DateTime? _savedAt(RelPath path) {
    final micros = int.tryParse(path.value.split('.').first);
    return micros == null
        ? null
        : DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }
}
