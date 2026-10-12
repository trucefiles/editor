/// Core of Truce: files, sync-tool conventions and conflict handling.
///
/// Pure Dart, no UI. The app uses only what this library exports.
///
/// Layers, bottom up:
/// 1. `storage`: byte-level file access under one folder ([FileStore]).
/// 2. `sync`: a sync tool's file-name rules ([SyncAdapter]).
/// 3. `filter`: which files and folders Truce looks at ([FileFilter]).
/// 4. `filetypes`: which [FileType] a file is ([FileTypeDetector]).
/// 5. `conflicts`: resolving conflicts ([ConflictService]), found by each
///    sync tool's [ConflictSource] and merged per file type
///    ([ConflictHandler]).
library;

export 'src/common/result.dart';
export 'src/conflicts/conflict.dart';
export 'src/conflicts/conflict_handler.dart';
export 'src/conflicts/conflict_service.dart';
export 'src/conflicts/conflict_source.dart';
export 'src/conflicts/resolution.dart';
export 'src/filetypes/file_type.dart';
export 'src/filetypes/file_type_detector.dart';
export 'src/filter/file_filter.dart';
export 'src/storage/file_store.dart';
export 'src/storage/rel_path.dart';
export 'src/sync/sync_adapter.dart';
