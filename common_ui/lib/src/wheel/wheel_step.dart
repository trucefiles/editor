import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// How far a mouse wheel step [event] goes, as Flutter's scroll views in
/// [context] read it: `dx` sideways, `dy` down. A held axis modifier of
/// the scroll behavior (Shift by default) turns a step sideways, as does
/// a wheel that tilts. `null` for any other pointer signal (a touchpad's
/// included).
Offset? mouseWheelStep(BuildContext context, PointerSignalEvent event) {
  if (event case PointerScrollEvent(
    kind: PointerDeviceKind.mouse,
    :final scrollDelta,
  )) {
    final modifiers = ScrollConfiguration.of(context).pointerAxisModifiers;
    final flipped = HardwareKeyboard.instance.logicalKeysPressed.any(
      modifiers.contains,
    );
    return flipped ? Offset(scrollDelta.dy, scrollDelta.dx) : scrollDelta;
  }
  return null;
}
