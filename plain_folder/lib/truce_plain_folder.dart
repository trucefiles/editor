/// Plain folders for Truce: folders that no sync tool syncs, or one the
/// app doesn't know, behind the interfaces of `truce_core`.
///
/// Pure Dart, no UI. Generic code never imports this library; only the
/// app's sync-tool wiring does, through [PlainFolderTool].
library;

export 'src/plain_conflict_names.dart';
export 'src/plain_folder_place.dart';
export 'src/plain_folder_rules.dart';
export 'src/plain_folder_tool.dart';
