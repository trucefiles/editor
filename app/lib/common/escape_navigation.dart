import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Makes Esc close the top screen or form, as the back arrow does, so it
/// works the same on every one; a screen's own leave check still runs.
/// While a dialog, menu or sheet has the keyboard focus, Esc is theirs:
/// they close themselves as Flutter has them do.
///
/// Flutter's own Esc can't do it: each screen answers it first, and a
/// screen answers that it can't be dismissed. So Esc is this app's, and
/// left to Flutter's where it has its own use.
class EscapeNavigation extends StatelessWidget {
  const EscapeNavigation({
    required this.navigator,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.escape): LeaveScreenIntent(),
    },
    child: Actions(
      actions: {LeaveScreenIntent: _LeaveScreen(navigator)},
      child: child,
    ),
  );
}

/// Esc on a screen: leave it.
class LeaveScreenIntent extends Intent {
  const LeaveScreenIntent();
}

class _LeaveScreen extends ContextAction<LeaveScreenIntent> {
  _LeaveScreen(this.navigator);

  final GlobalKey<NavigatorState> navigator;

  /// Only while the focus is on a screen, or on none; not in an open
  /// menu, a dialog or a sheet, where Esc is Flutter's own.
  @override
  bool isEnabled(LeaveScreenIntent intent, [BuildContext? context]) =>
      context != null &&
      !(MenuController.maybeOf(context)?.isOpen ?? false) &&
      switch (ModalRoute.of(context)) {
        null || PageRoute() => true,
        _ => false,
      };

  @override
  Object? invoke(LeaveScreenIntent intent, [BuildContext? context]) =>
      navigator.currentState?.maybePop();
}
