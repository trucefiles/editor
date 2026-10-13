import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Makes the mouse's back button close the top screen or dialog, like the
/// app bar's back arrow. Flutter leaves that button unhandled.
class MouseBackNavigation extends StatelessWidget {
  const MouseBackNavigation({
    required this.navigator,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigator;
  final Widget child;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      if (event.buttons & kBackMouseButton != 0) {
        navigator.currentState?.maybePop();
      }
    },
    child: child,
  );
}
