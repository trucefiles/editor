import 'package:flutter/material.dart';

import '../../folders/ui/folder_badge.dart';
import '../conflicts_controller.dart';

/// A note deleted on one device while edited on another: only the edited
/// version is left. Opens the conflict screen to restore or discard it.
class OrphanCard extends StatelessWidget {
  const OrphanCard(this.conflict, {required this.onTap, super.key});

  final FolderConflict conflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                conflict.conflict.mainPath.name,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              const Expanded(
                child: Text(
                  'Deleted on one device, edited on another. '
                  'Tap to restore or discard.',
                ),
              ),
              FolderBadge(conflict.folder),
            ],
          ),
        ),
      ),
    );
  }
}
