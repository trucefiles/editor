import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/empty_state.dart';
import '../../folders/ui/folder_badge.dart';
import '../../scan/folder_scans_controller.dart';
import '../folder_conflicts.dart';
import 'conflict_banner.dart';

/// Every pending sync conflict of all folders; tapping one opens it to
/// resolve.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scans = ref.watch(folderScansProvider).value;
    final conflicts = scans?.conflicts.all ?? const <FolderConflict>[];
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
                    title: Text(
                      scans?.findNote(conflict.key)?.title ??
                          conflict.conflict.mainPath.name,
                    ),
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
