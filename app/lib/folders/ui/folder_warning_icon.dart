import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_folders/truce_folders.dart';

import '../open_folders_wiring.dart';
import 'folder_notice_text.dart';

/// A small warning sign if the plugin warns about [folder]; the full
/// text is on the folders screen. Shows nothing otherwise.
class FolderWarningIcon extends ConsumerWidget {
  const FolderWarningIcon(this.folder, {super.key});

  final Folder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(folderNoticesProvider(folder.id)).value;
    final warnings = [...?notices?.where((notice) => notice.isWarning)];
    if (warnings.isEmpty) return const SizedBox.shrink();
    final tool = ref.watch(folderServicesProvider(folder.id)).pluginName;
    return Tooltip(
      message: warnings.map((warning) => warning.shortText(tool)).join('\n'),
      child: Icon(
        Icons.warning_amber,
        size: 16,
        color: Theme.of(context).colorScheme.error,
      ),
    );
  }
}
