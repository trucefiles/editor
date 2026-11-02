/// Syncthing's conventions for Truce: its file names, conflict copies,
/// folder markers and timing quirks, behind the plugin interface of
/// `truce_core`.
///
/// Pure Dart, no UI. Generic code never imports this library; only the
/// app's plugin wiring and Syncthing's add page do, through
/// [SyncthingPlugin].
library;

export 'src/sync_check.dart';
export 'src/syncthing_conflict_name.dart';
export 'src/syncthing_folder.dart';
export 'src/syncthing_folder_notices.dart';
export 'src/syncthing_mtime_window_store.dart';
export 'src/syncthing_plugin.dart';
export 'src/syncthing_root_search.dart';
export 'src/syncthing_rules.dart';
export 'src/syncthing_state.dart';
export 'src/syncthing_sync_check.dart';
