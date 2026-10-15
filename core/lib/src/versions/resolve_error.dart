import '../storage/file_store.dart';

/// Why keeping one of two versions of a file failed.
enum ResolveError {
  changedSinceScan,
  backupFailed,
  accessDenied,
  ioFailure;

  /// Why a write failed: a file that is missing, already exists or changed
  /// means the folder no longer matches what the user saw.
  static ResolveError ofStore(StoreError error) => switch (error) {
    StoreError.notFound ||
    StoreError.alreadyExists ||
    StoreError.changedSinceRead => changedSinceScan,
    StoreError.accessDenied => accessDenied,
    StoreError.ioFailure => ioFailure,
  };
}
