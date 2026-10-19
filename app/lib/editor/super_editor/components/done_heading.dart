import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

/// The heading of a list's "Done" section, with its count; a tap folds or
/// unfolds the section.
class DoneHeading extends StatelessWidget {
  const DoneHeading(this.entry, {this.onTap, super.key});

  final DoneHeadingEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(entry.collapsed ? Icons.chevron_right : Icons.expand_more),
            const SizedBox(width: 8),
            Text(
              'Done (${entry.count})',
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
