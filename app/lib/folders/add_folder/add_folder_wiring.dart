import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../platform/platform_wiring.dart';
import '../../sync_tool/base_folder_services.dart';
import '../../sync_tool/sync_tools.dart';
import '../folders_controller.dart';
import 'add_folder_flow.dart';

/// What adding a folder works with, wired.
final addFolderWorkProvider = Provider<AddFolderWork>((ref) {
  final tools = ref.watch(syncToolsProvider);
  final platform = ref.watch(platformFactsProvider);
  return AddFolderWork(
    tools: tools.all,
    markersOf: (path) => baseFolderMarkers(path, platform),
    namesOf: ref.watch(subfolderNamesProvider),
    isToolFolder: tools.isToolFolder,
    add: ref.read(foldersProvider.notifier).add,
  );
});
