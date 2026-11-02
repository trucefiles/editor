import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_syncthing_ui/truce_syncthing_ui.dart';

import '../../platform/folder_picker.dart';
import '../pick_folder.dart';
import '../wired_plugin.dart';

/// Syncthing, as the app registers it, for folders on [disk], picked with
/// [picker]. The only file of the app that knows it.
WiredPlugin syncthingPlugin(LocalDisk disk, FolderPicker picker) {
  final plugin = SyncthingPlugin(disk);
  return WiredPlugin(
    plugin,
    (context) => addSyncthingFolders(
      context,
      plugin: plugin,
      pick: () => pickFolder(context, picker),
    ),
  );
}
