import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

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

  static Future<bool> _discard(BuildContext context) => showConfirmDialog(
    context,
    title: 'Discard changes?',
    yes: 'Discard',
    no: 'Keep editing',
  );
}
