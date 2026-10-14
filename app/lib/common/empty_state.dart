import 'package:flutter/material.dart';

/// A screen with nothing to show yet: a large tinted [icon] above a short
/// [text], centered, with an optional [action] below.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.text,
    this.action,
    super.key,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: 16,
          children: [
            Icon(icon, size: 96, color: theme.colorScheme.primary),
            Text(
              text,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
