import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../folder_services.dart';
import '../note_folder.dart';
import 'folder_notice_text.dart';

/// Everything the sync tool has to tell about [folder], one line each:
/// warnings in the error color. Shows nothing while checking or when there
/// is nothing to tell.
class FolderNoticesView extends ConsumerWidget {
  const FolderNoticesView(this.folder, {super.key});

  final NoteFolder folder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(folderNoticesProvider(folder.location)).value;
    if (notices == null || notices.isEmpty) return const SizedBox.shrink();
    final tool = ref
        .watch(folderServicesProvider(folder.location))
        .syncToolName;
    final error = Theme.of(context).colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final notice in notices)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 8,
              children: [
                Icon(
                  notice.isWarning ? Icons.warning_amber : Icons.info_outline,
                  size: 18,
                  color: notice.isWarning ? error : null,
                ),
                Expanded(
                  child: Text(
                    notice.text(tool),
                    style: TextStyle(color: notice.isWarning ? error : null),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
