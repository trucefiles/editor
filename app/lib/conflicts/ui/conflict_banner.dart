import 'package:flutter/material.dart';

import '../folder_conflicts.dart';
import 'conflict_screen.dart';

/// Tells that an open note has another version from a sync conflict.
class ConflictBanner extends StatelessWidget {
  const ConflictBanner(this.conflict, {super.key});

  final FolderConflict conflict;

  @override
  Widget build(BuildContext context) {
    final count = conflict.conflict.copies.length;
    return MaterialBanner(
      leading: const Icon(Icons.call_split),
      content: Text(
        count == 1
            ? 'Another device saved a different version.'
            : 'Other devices saved $count different versions.',
      ),
      actions: [
        TextButton(
          onPressed: () => openConflict(context, conflict),
          child: const Text('Compare'),
        ),
      ],
    );
  }
}

Future<void> openConflict(BuildContext context, FolderConflict conflict) =>
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ConflictScreen(conflict)),
    );
