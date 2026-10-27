import 'package:flutter/material.dart';

/// A small "Conflict" pill: the document has versions from a sync conflict.
class ConflictLabel extends StatelessWidget {
  const ConflictLabel({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Sync conflict',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 2,
          children: [
            Icon(Icons.call_split, size: 14, color: colors.onError),
            Text(
              'Conflict',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.onError),
            ),
          ],
        ),
      ),
    );
  }
}
