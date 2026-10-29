import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/empty_state.dart';
import '../../documents/ui/listed_document.dart';
import '../../folder_state/folder_state_controller.dart';
import '../../folders/ui/folder_badge.dart';
import 'conflict_banner.dart';

/// Every pending sync conflict of all folders; tapping one opens it to
/// resolve.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts =
        ref.watch(folderContentsProvider).value?.conflicts.all ??
        const <FolderConflict>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Conflicts')),
      body: conflicts.isEmpty
          ? const EmptyState(
              icon: Icons.check_circle_outline,
              text: 'No sync conflicts.',
            )
          : ListView(
              children: [
                for (final conflict in conflicts)
                  ListTile(
                    leading: const Icon(Icons.call_split),
                    title: _Title(conflict),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_summary(conflict)),
                        FolderBadge(
                          conflict.folder,
                          file: conflict.conflict.mainPath,
                        ),
                      ],
                    ),
                    onTap: () => openConflict(context, conflict),
                  ),
              ],
            ),
    );
  }

  static String _summary(FolderConflict conflict) {
    if (conflict.conflict.isOrphaned) {
      return 'Deleted on one device, edited on another.';
    }
    final count = conflict.conflict.copies.length;
    return count == 1 ? '1 other version' : '$count other versions';
  }
}

/// The title of [conflict]'s document, as its card shows it.
class _Title extends ConsumerWidget {
  const _Title(this.conflict);

  final FolderConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Text(watchTitle(ref, conflict.key));
}
