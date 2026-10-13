import 'dart:typed_data';

import '../common/result.dart';
import '../conflicts/conflict.dart';
import '../conflicts/conflict_source.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'syncthing_conflict_name.dart';

/// Syncthing's conflict copies: files next to their main file, named by
/// [SyncthingConflictName]. A copy's id is its path, as given by
/// `groupSyncthingConflicts`.
final class SyncthingConflictSource implements ConflictSource {
  const SyncthingConflictSource(this._store, {this._clock = DateTime.now});

  /// Gives up on a free name after this many seconds' worth of tries.
  static const _maxAttempts = 60;

  final FileStore _store;
  final DateTime Function() _clock;

  @override
  Future<Result<Uint8List, StoreError>> read(ConflictCopy copy) async {
    final read = await _store.read(_path(copy));
    return switch (read) {
      Ok(value: final content) when content.version != copy.version =>
        const Err(StoreError.changedSinceRead),
      Ok(value: final content) => Ok(content.bytes),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<void, StoreError>> discard(ConflictCopy copy) =>
      _store.delete(_path(copy), ifUnchanged: copy.version);

  /// Names hold the time to the second; a taken name moves on a second.
  @override
  Future<Result<void, StoreError>> add(
    RelPath mainPath,
    Uint8List bytes,
  ) async {
    final now = _clock();
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final at = now.add(Duration(seconds: attempt));
      final name = SyncthingConflictName.format(mainPath.name, at);
      switch (await _store.create(mainPath.sibling(name)!, bytes)) {
        case Ok():
          return const Ok(null);
        case Err(error: StoreError.alreadyExists):
          continue;
        case Err(:final error):
          return Err(error);
      }
    }
    return const Err(StoreError.alreadyExists);
  }

  /// Ids are paths made by the scan, so they always parse.
  RelPath _path(ConflictCopy copy) => RelPath.parse(copy.id)!;
}
