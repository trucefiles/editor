import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lies over [child] and turns each sideways step of a mouse wheel
/// (Shift and the wheel, or a wheel that tilts) into one page: [onNext]
/// for down or right, [onPrevious] for up or left. It claims the step
/// before the views below see it: their pages would move by a few pixels
/// and snap back. Every other pointer, a touchpad's too, passes through.
class SidewaysWheel extends StatelessWidget {
  const SidewaysWheel({
    required this.onPrevious,
    required this.onNext,
    required this.child,
    super.key,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  /// How far [event] goes sideways; 0 if it isn't a sideways wheel step.
  static double _sideways(PointerSignalEvent event) => switch (event) {
    PointerScrollEvent(kind: PointerDeviceKind.mouse, :final scrollDelta)
        when HardwareKeyboard.instance.isShiftPressed =>
      scrollDelta.dy != 0 ? scrollDelta.dy : scrollDelta.dx,
    PointerScrollEvent(kind: PointerDeviceKind.mouse, :final scrollDelta)
        when scrollDelta.dy == 0 =>
      scrollDelta.dx,
    _ => 0,
  };

  void _onSignal(PointerSignalEvent event) {
    final delta = _sideways(event);
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => delta > 0 ? onNext() : onPrevious(),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      // On top, so it is asked first; translucent, so the pointer still
      // reaches the views below.
      Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: _onSignal,
        ),
      ),
    ],
  );
}
