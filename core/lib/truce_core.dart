/// Core of Truce: files, sync-tool conventions and conflict handling.
///
/// Pure Dart, no UI. The app uses only what this library exports.
///
/// Layers, bottom up:
/// 1. `storage`: byte-level file access under one folder ([FileStore]).
/// 2. `sync`: a sync tool's file-name rules ([SyncAdapter]) and whether it
///    syncs a folder ([SyncCheck]).
/// 3. `filter`: which files and folders Truce looks at ([FileFilter]).
/// 4. `filetypes`: which [FileType] a file is ([FileTypeDetector]).
/// 5. `conflicts`: reading and resolving conflicts ([ConflictService]),
///    whose copies each sync tool keeps in its [ConflictSource], merged per
///    file type ([ConflictHandler]).
/// 6. `scan`: a folder's files and conflicts in one go ([FolderScanner]).
/// 7. `text`: decoding files for editing without changing their byte style
///    ([TextFile]).
/// 8. `markdown`: Markdown documents as line-level edits ([Checklist]).
/// 9. `marks`: pins and colors of notes, synced inside the folder
///    ([NoteMarks]).
///
/// Implementations sit next to their interface; everything specific to
/// Syncthing is in `syncthing`.
library;

export 'src/common/result.dart';
export 'src/conflicts/conflict.dart';
export 'src/conflicts/conflict_backups.dart';
export 'src/conflicts/conflict_handler.dart';
export 'src/conflicts/conflict_service.dart';
export 'src/conflicts/conflict_source.dart';
export 'src/conflicts/default_conflict_service.dart';
export 'src/conflicts/resolution.dart';
export 'src/filetypes/extension_file_type_detector.dart';
export 'src/filetypes/file_type.dart';
export 'src/filetypes/file_type_detector.dart';
export 'src/filter/default_file_filter.dart';
export 'src/filter/file_filter.dart';
export 'src/markdown/checklist.dart';
export 'src/marks/note_mark.dart';
export 'src/marks/note_marks.dart';
export 'src/scan/folder_scanner.dart';
export 'src/storage/file_store.dart';
export 'src/storage/folder_names.dart';
export 'src/storage/local_file_store.dart';
export 'src/storage/rel_path.dart';
export 'src/storage/restamping_file_store.dart';
export 'src/sync/sync_adapter.dart';
export 'src/sync/sync_check.dart';
export 'src/syncthing/syncthing_adapter.dart';
export 'src/syncthing/syncthing_conflict_source.dart';
export 'src/syncthing/syncthing_folder_scanner.dart';
export 'src/syncthing/syncthing_sync_check.dart';
export 'src/text/text_file.dart';
