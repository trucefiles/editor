import 'package:flutter/material.dart';

/// A small "Conflict" pill: the file has versions from a sync conflict.
/// Without [word], only its icon, where room is short.
class ConflictLabel extends StatelessWidget {
  const ConflictLabel({this.word = true, super.key});

  final bool word;

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
            if (word)
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
