import 'package:truce_core/truce_core.dart';
import 'package:truce_plain_folder/truce_plain_folder.dart';

/// Plain folders, as the app registers them, for folders on [disk]. The
/// only file of the app that knows them.
SyncTool plainFolderTool(LocalDisk disk) => PlainFolderTool(disk);
