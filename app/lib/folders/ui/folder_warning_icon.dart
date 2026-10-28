import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync_tool/base_folder_services.dart';
import '../document_folder.dart';
import 'folder_notice_text.dart';

/// A small warning sign if the sync tool warns about [folder]; the full
/// text is on the folders screen. Shows nothing otherwise.
class FolderWarningIcon extends ConsumerWidget {
  const FolderWarningIcon(this.folder, {super.key});

  final DocumentFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(folderNoticesProvider(folder.base)).value;
    final warnings = [...?notices?.where((notice) => notice.isWarning)];
    if (warnings.isEmpty) return const SizedBox.shrink();
    final tool = ref
        .watch(baseFolderServicesProvider(folder.base))
        .syncToolName;
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
