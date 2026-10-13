import 'dart:typed_data';

import '../common/result.dart';
import '../storage/file_store.dart';
import '../storage/rel_path.dart';
import 'conflict.dart';
import 'conflict_backups.dart';
import 'conflict_service.dart';
import 'conflict_source.dart';
import 'resolution.dart';

/// [ConflictService] for phase 0: the user picks a side, nothing is merged.
final class DefaultConflictService implements ConflictService {
  DefaultConflictService({
    required this._folder,
    required this._source,
    required this._backups,
    this._clock = DateTime.now,
  });

  final FileStore _folder;
  final ConflictSource _source;
  final ConflictBackups _backups;
  final DateTime Function() _clock;

  @override
  Future<Result<Uint8List, StoreError>> readMain(Conflict conflict) async {
    final main = conflict.main;
    if (main == null) return const Err(StoreError.notFound);
    return switch (await _folder.read(conflict.mainPath)) {
      Ok(:final value) when value.version != main.version => const Err(
        StoreError.changedSinceRead,
      ),
      Ok(:final value) => Ok(value.bytes),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<Uint8List, StoreError>> readCopy(ConflictCopy copy) =>
      _source.read(copy);

  @override
  Future<Result<void, StoreError>> keepAsConflict(
    RelPath mainPath,
    Uint8List bytes,
  ) => _source.add(mainPath, bytes);

  @override
  Future<Result<void, ResolveError>> resolve(
    Conflict conflict,
    ConflictCopy copy,
    Resolution resolution,
  ) async {
    final Uint8List other;
    switch (await _source.read(copy)) {
      case Ok(:final value):
        other = value;
      case Err(:final error):
        return Err(_resolveError(error));
    }

    Uint8List? current;
    if (!conflict.isOrphaned) {
      switch (await readMain(conflict)) {
        case Ok(:final value):
          current = value;
        case Err(:final error):
          return Err(_resolveError(error));
      }
    }

    final backedUp = await _backups.save(
      at: _clock(),
      mainPath: conflict.mainPath,
      current: current,
      other: other,
    );
    if (backedUp is Err) return const Err(ResolveError.backupFailed);

    final written = switch (resolution) {
      KeepCurrent() => const Ok<void, StoreError>(null),
      KeepOther() => await _writeMain(conflict, other),
    };
    if (written case Err(:final error)) return Err(_resolveError(error));

    return switch (await _source.discard(copy)) {
      Ok() => const Ok(null),
      Err(:final error) => Err(_resolveError(error)),
    };
  }

  @override
  Future<Result<void, StoreError>> pruneBackups({
    required DateTime olderThan,
  }) => _backups.prune(olderThan: olderThan);

  /// Replaces the main file, or restores it if the conflict is orphaned.
  Future<Result<void, StoreError>> _writeMain(
    Conflict conflict,
    Uint8List bytes,
  ) async {
    final written = switch (conflict.main) {
      null => await _folder.create(conflict.mainPath, bytes),
      final main => await _folder.replace(
        conflict.mainPath,
        bytes,
        ifUnchanged: main.version,
      ),
    };
    return switch (written) {
      Ok() => const Ok(null),
      Err(:final error) => Err(error),
    };
  }

  /// A file that is missing, already exists or changed means the folder no
  /// longer matches the scan.
  static ResolveError _resolveError(StoreError error) => switch (error) {
    StoreError.notFound ||
    StoreError.alreadyExists ||
    StoreError.changedSinceRead => ResolveError.changedSinceScan,
    StoreError.accessDenied => ResolveError.accessDenied,
    StoreError.ioFailure => ResolveError.ioFailure,
  };
}
