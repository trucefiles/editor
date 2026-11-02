import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_folders/truce_folders.dart';

import '../platform/folder_picker.dart';
import '../platform/platform_wiring.dart';
import 'local_folder/local_folder_wiring.dart';
import 'syncthing/syncthing_wiring.dart';
import 'wired_plugin.dart';

/// The plugins the app works with, each with its add page: the one place
/// that registers them, at compile time. Made once: each plugin holds its
/// state.
final wiredPluginsProvider = Provider<List<WiredPlugin>>((ref) {
  final disk = ref.watch(localDiskProvider);
  final picker = ref.watch(folderPickerProvider);
  return [syncthingPlugin(disk, picker), localFolderPlugin(disk, picker)];
});

/// The plugins, for the folder list and the open folders.
final folderPluginsProvider = Provider<FolderPlugins>(
  (ref) => FolderPlugins([
    for (final wired in ref.watch(wiredPluginsProvider)) wired.plugin,
  ]),
);
