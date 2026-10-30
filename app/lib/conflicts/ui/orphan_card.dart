import 'package:flutter/material.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/card_frame.dart';
import '../../folders/ui/folder_badge.dart';

/// A document deleted on one device while edited on another: only the edited
/// version is left, shown at the document text zoom like other document cards.
/// Opens the conflict screen to restore or discard it.
class OrphanCard extends StatelessWidget {
  const OrphanCard(this.conflict, {required this.onTap, super.key});

  final FolderConflict conflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => CardFrame(
    color: Theme.of(context).colorScheme.errorContainer,
    onTap: onTap,
    title: conflict.conflict.mainPath.name,
    body: const CardLines(
      'Deleted on one device, edited on another. Tap to restore or discard.',
    ),
    footer: Row(
      children: [
        Flexible(
          child: FolderBadge(conflict.folder, file: conflict.conflict.mainPath),
        ),
      ],
    ),
  );
}
