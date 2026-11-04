import 'package:flutter/material.dart';

/// Asks before the form [child] closes without saving (back, Esc, a tap
/// outside) while [changed] tells that the user changed something;
/// leaves only if they discard the changes. Save closes it unasked.
class LeaveCheck extends StatelessWidget {
  const LeaveCheck({required this.changed, required this.child, super.key});

  final bool Function() changed;
  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      if (changed() && !await _discard(context)) return;
      if (context.mounted) Navigator.pop(context);
    },
    child: child,
  );

  static Future<bool> _discard(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      ) ??
      false;
}
