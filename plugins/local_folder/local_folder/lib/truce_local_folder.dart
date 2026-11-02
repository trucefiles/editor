/// Local folders for Truce: folders that no sync tool syncs, or one the
/// app doesn't know, behind the plugin interface of `truce_core`.
///
/// Pure Dart, no UI. Generic code never imports this library; only the
/// app's plugin wiring and the Local folder add page do, through
/// [LocalFolderPlugin].
library;

export 'src/local_conflict_names.dart';
export 'src/local_directory.dart';
export 'src/local_folder_plugin.dart';
export 'src/local_folder_rules.dart';
export 'src/local_folder_state.dart';
