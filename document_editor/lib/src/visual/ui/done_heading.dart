import 'package:flutter/material.dart';

/// The heading of a list's "Done" section, with the [count] of its
/// items; a tap folds or unfolds the section, [collapsed] or not.
class DoneHeading extends StatelessWidget {
  const DoneHeading({
    required this.count,
    required this.collapsed,
    required this.onTap,
    super.key,
  });

  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
            const SizedBox(width: 8),
            Text(
              'Done ($count)',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
