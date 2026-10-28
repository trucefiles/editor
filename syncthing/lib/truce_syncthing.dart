/// Syncthing's conventions for Truce: its file names, conflict copies,
/// folder markers and timing quirks, behind the interfaces of `truce_core`.
///
/// Pure Dart, no UI. Generic code never imports this library; only the
/// app's sync-tool wiring does, through [SyncthingTool].
library;

export 'src/syncthing_conflict_name.dart';
export 'src/syncthing_folder_notices.dart';
export 'src/syncthing_mtime_window_store.dart';
export 'src/syncthing_place.dart';
export 'src/syncthing_rules.dart';
export 'src/syncthing_sync_check.dart';
export 'src/syncthing_tool.dart';
