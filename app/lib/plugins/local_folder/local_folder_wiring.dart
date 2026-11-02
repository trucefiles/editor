import 'package:truce_core/truce_core.dart';
import 'package:truce_local_folder/truce_local_folder.dart';
import 'package:truce_local_folder_ui/truce_local_folder_ui.dart';

import '../../platform/folder_picker.dart';
import '../pick_folder.dart';
import '../wired_plugin.dart';

/// Local folders, as the app registers them, for folders on [disk],
/// picked with [picker]. The only file of the app that knows them.
WiredPlugin localFolderPlugin(LocalDisk disk, FolderPicker picker) {
  final plugin = LocalFolderPlugin(disk);
  return WiredPlugin(
    plugin,
    (context) => addLocalFolder(
      context,
      plugin: plugin,
      pick: () => pickFolder(context, picker),
    ),
  );
}
