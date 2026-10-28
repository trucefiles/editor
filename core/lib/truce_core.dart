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
/// 5. `filetypes`: which [FileType] a file is ([FileTypeDetector]), and
///    what each type gives lists ([FileTypeSupport]).
/// 6. `conflicts`: reading and resolving conflicts ([ConflictService]),
///    whose copies each sync tool keeps in its [ConflictSource], merged per
///    file type ([ConflictHandler]).
/// 7. `restore`: putting a backup back, kept like any choice between two
///    versions ([BackupRestore]).
/// 8. `scan`: a folder's files and conflicts in one go ([FolderScanner]).
/// 9. `text`: decoding files for editing without changing their byte style
///    ([TextFile]); a text as lines that keep their ids while edited
///    ([TextLines]).
/// 10. `marks`: colors of documents, synced inside the folder
///     ([DocumentMarks]).
/// 11. `changes`: changes to a folder's files as they happen
///     ([FolderChanges]).
/// 12. `reach`: whether a folder can be reached, from how accesses to its
///     files go ([FolderReach]).
///
/// 13. `scans`: when the folders are scanned, and which scan is the
///     latest ([ScansOwner]); any folder and result type.
/// 14. `documents`: an open document's file, kept on the device and in
///     the folder in step with changes elsewhere, by its owner
///     ([FileOwner]); and what every type's editor shares: the page's
///     requests and notices ([EditorRequest], [EditorNotice]), the save
///     timing ([SaveClock]) and undo ([EditHistory]), handled alike
///     ([EditorSteps]); any document type, any sync tool.
///
/// `owners` holds how an owner of a domain's state runs ([Owner]): by a
/// pure machine ([MachineOwner]) or by plain code ([SimpleOwner]); and
/// how a question to an owner gets its answer ([ask]).
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
export 'src/common/moment.dart';
export 'src/common/most_used.dart';
export 'src/common/result.dart';
export 'src/compare/compare_owner.dart';
export 'src/conflicts/conflict.dart';
export 'src/conflicts/conflict_handler.dart';
export 'src/conflicts/conflict_service.dart';
export 'src/conflicts/conflict_source.dart';
export 'src/conflicts/default_conflict_service.dart';
export 'src/documents/editor/editor_book.dart';
export 'src/documents/editor/editor_contract.dart';
export 'src/documents/editor/editor_steps.dart';
export 'src/documents/editor/history/edit_history.dart';
export 'src/documents/editor/history/text_change.dart';
export 'src/documents/editor/history/typing.dart';
export 'src/documents/editor/save_clock.dart';
export 'src/documents/file_owner/file_owner.dart';
export 'src/documents/version.dart';
export 'src/filetypes/extension_file_type_detector.dart';
export 'src/filetypes/file_type.dart';
export 'src/filetypes/file_type_detector.dart';
export 'src/filetypes/file_type_support.dart';
export 'src/filter/any_file_filter.dart';
export 'src/filter/default_file_filter.dart';
export 'src/filter/file_filter.dart';
export 'src/marks/document_mark.dart';
export 'src/marks/document_marks.dart';
export 'src/owners/ask.dart';
export 'src/owners/effects.dart';
export 'src/owners/machine.dart';
export 'src/owners/machine_owner.dart';
export 'src/owners/owner.dart';
export 'src/owners/simple_owner.dart';
export 'src/owners/timers.dart';
export 'src/reach/folder_reach.dart';
export 'src/reach/reach_reporting_store.dart';
export 'src/restore/backup_restore.dart';
export 'src/scan/folder_scanner.dart';
export 'src/scans/scans_owner.dart';
export 'src/storage/file_store.dart';
export 'src/storage/folder_names.dart';
export 'src/storage/local_file_store.dart';
export 'src/storage/rel_path.dart';
export 'src/sync/folder_notices.dart';
export 'src/sync/sync_adapter.dart';
export 'src/sync/sync_check.dart';
export 'src/text/lines/editable_lines.dart';
export 'src/text/lines/line.dart';
export 'src/text/lines/line_change.dart';
export 'src/text/lines/line_endings.dart';
export 'src/text/lines/text_lines.dart';
export 'src/text/text_file.dart';
export 'src/versions/resolution.dart';
export 'src/versions/resolve_error.dart';
