import 'package:truce_core/truce_core.dart';
import 'package:truce_local_folder/truce_local_folder.dart';

/// Local folders, as the app registers them, for folders on [disk]. The
/// only file of the app that knows them.
SyncTool localFolderTool(LocalDisk disk) => LocalFolderTool(disk);
