import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Makes the mouse's back button close the top screen or dialog, like the
/// app bar's back arrow, while [enabled]: Flutter leaves that button
/// unhandled where the system doesn't turn it into Back itself.
class MouseBackNavigation extends StatelessWidget {
  const MouseBackNavigation({
    required this.navigator,
    required this.enabled,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (enabled && event.buttons & kBackMouseButton != 0) {
        navigator.currentState?.maybePop();
      }
    },
    child: child,
  );
}
