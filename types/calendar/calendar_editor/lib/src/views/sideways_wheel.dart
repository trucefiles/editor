import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Lies over [child] and turns sideways steps of a mouse wheel (Shift and
/// the wheel, or a wheel that tilts) into page moves: [onNext] for down
/// or right, [onPrevious] for up or left. One page at a time: steps that
/// come while a page still moves are dropped, so a fast or fine-grained
/// wheel can't skip or race through pages. It claims each step before the
/// views below see it: their pages would move by a few pixels and snap
/// back. Every other pointer, a touchpad's too, passes through.
class SidewaysWheel extends StatefulWidget {
  const SidewaysWheel({
    required this.onPrevious,
    required this.onNext,
    required this.child,
    super.key,
  });

  /// Moves one page back; done when the move ends.
  final Future<void> Function() onPrevious;

  /// Moves one page on; done when the move ends.
  final Future<void> Function() onNext;

  final Widget child;

  @override
  State<SidewaysWheel> createState() => _SidewaysWheelState();
}

class _SidewaysWheelState extends State<SidewaysWheel> {
  bool _moving = false;

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
      (_) => _move(delta > 0 ? widget.onNext : widget.onPrevious),
    );
  }

  Future<void> _move(Future<void> Function() page) async {
    if (_moving) return;
    _moving = true;
    try {
      await page();
    } finally {
      _moving = false;
    }
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
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
