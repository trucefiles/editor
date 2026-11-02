import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';

/// Syncthing, as the app registers it, for folders on [disk]. The only
/// file of the app that knows it.
SyncTool syncthingTool(LocalDisk disk) => SyncthingTool(disk);
