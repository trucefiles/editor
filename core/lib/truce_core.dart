/// Core of Truce: files, sync-tool conventions and conflict handling.
///
/// Pure Dart, no UI. The app uses only what this library exports.
///
/// Layers, bottom up:
/// 1. `storage`: byte-level file access under one folder ([FileStore]).
/// 2. `sync`: what a sync tool's file names mean ([SyncAdapter]).
/// 3. `conflicts`: finding and resolving conflict copies ([ConflictService]),
///    with per-file-type merge logic ([ConflictHandler]).
library;

export 'src/common/result.dart';
export 'src/conflicts/conflict.dart';
export 'src/conflicts/conflict_handler.dart';
export 'src/conflicts/conflict_service.dart';
export 'src/conflicts/resolution.dart';
export 'src/storage/file_store.dart';
export 'src/storage/rel_path.dart';
export 'src/sync/sync_adapter.dart';
