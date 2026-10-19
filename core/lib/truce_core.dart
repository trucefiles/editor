/// Core of Truce: files, sync-tool interfaces and conflict handling.
///
/// Pure Dart, no UI. The app uses only what this library exports.
///
/// Layers, bottom up:
/// 1. `storage`: byte-level file access under one folder ([FileStore]).
/// 2. `backups`: copies of files in app storage ([FileBackups]), made
///    before edits and before the user keeps one of two versions.
/// 3. `sync`: a sync tool's file-name rules ([SyncAdapter]), whether it
///    syncs a folder ([SyncCheck]) and what to tell the user about a folder
///    ([FolderNotices]).
/// 4. `filter`: which files and folders Truce looks at ([FileFilter]).
/// 5. `filetypes`: which [FileType] a file is ([FileTypeDetector]).
/// 6. `conflicts`: reading and resolving conflicts ([ConflictService]),
///    whose copies each sync tool keeps in its [ConflictSource], merged per
///    file type ([ConflictHandler]).
/// 7. `restore`: putting a backup back, kept like any choice between two
///    versions ([BackupRestore]).
/// 8. `scan`: a folder's files and conflicts in one go ([FolderScanner]).
/// 9. `text`: decoding files for editing without changing their byte style
///    ([TextFile]).
/// 10. `markdown`: Markdown documents as line-level edits ([MarkdownLines]).
/// 11. `marks`: colors of notes, synced inside the folder
///    ([NoteMarks]).
/// 12. `changes`: changes to a folder's files as they happen
///    ([FolderChanges]).
/// 13. `reach`: whether a folder can be reached, from how accesses to its
///    files go ([FolderReach]).
///
/// `versions` holds what conflicts and restore share: the user's choice
/// between two versions of a file ([Resolution]) and why keeping it failed
/// ([ResolveError]).
///
/// Implementations sit next to their interface. Nothing here is specific
/// to one sync tool; each tool's conventions live in a package of their
/// own (`truce_syncthing`).
library;

export 'src/backups/backup.dart';
export 'src/backups/file_backups.dart';
export 'src/changes/fallback_folder_changes.dart';
export 'src/changes/folder_changes.dart';
export 'src/changes/polled_folder_changes.dart';
export 'src/changes/watched_folder_changes.dart';
export 'src/common/keyed_task_queue.dart';
export 'src/common/result.dart';
export 'src/conflicts/conflict.dart';
export 'src/conflicts/conflict_handler.dart';
export 'src/conflicts/conflict_service.dart';
export 'src/conflicts/conflict_source.dart';
export 'src/conflicts/default_conflict_service.dart';
export 'src/filetypes/extension_file_type_detector.dart';
export 'src/filetypes/file_type.dart';
export 'src/filetypes/file_type_detector.dart';
export 'src/filter/any_file_filter.dart';
export 'src/filter/default_file_filter.dart';
export 'src/filter/file_filter.dart';
export 'src/markdown/markdown_lines.dart';
export 'src/marks/note_mark.dart';
export 'src/marks/note_marks.dart';
export 'src/reach/folder_reach.dart';
export 'src/reach/reach_reporting_store.dart';
export 'src/restore/backup_restore.dart';
export 'src/scan/folder_scanner.dart';
export 'src/storage/file_store.dart';
export 'src/storage/folder_names.dart';
export 'src/storage/local_file_store.dart';
export 'src/storage/rel_path.dart';
export 'src/sync/folder_notices.dart';
export 'src/sync/sync_adapter.dart';
export 'src/sync/sync_check.dart';
export 'src/text/text_file.dart';
export 'src/versions/resolution.dart';
export 'src/versions/resolve_error.dart';
