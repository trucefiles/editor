import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync_tool/base_folder_wiring.dart';
import '../../sync_tool/sync_tools_wiring.dart';
import '../folder_colors.dart';
import '../folders_controller.dart';
import 'add_folder_flow.dart';

/// What adding a folder works with, wired.
final addFolderWorkProvider = Provider<AddFolderWork>((ref) {
  final tools = ref.watch(syncToolsProvider);
  return AddFolderWork(
    tools: tools.all,
    colors: folderColors.keys.toList(),
    subfoldersOf: (base) => ref.read(subfolderNamesProvider(base)),
    add: ref.read(foldersProvider.notifier).add,
  );
});
