import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Turning the mouse wheel over [child] with Ctrl held asks for larger
/// text when turned up, smaller when turned down ([onZoom] with `true` or
/// `false`), one step per notch. Such a turn only zooms: nothing in
/// [child] scrolls by it. Without Ctrl, the wheel reaches [child] as
/// before.
class WheelToZoom extends SingleChildRenderObjectWidget {
  const WheelToZoom({required this.onZoom, required super.child, super.key});

  /// `true` for larger text, `false` for smaller.
  final ValueChanged<bool> onZoom;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderWheelToZoom(onZoom);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderWheelToZoom renderObject,
  ) => renderObject.onZoom = onZoom;
}

/// Hears pointer signals before anything in its child: of the ones that
/// claim a wheel turn, the first wins it, and the ones deeper inside (the
/// scroll views) are asked first otherwise.
class RenderWheelToZoom extends RenderProxyBox {
  RenderWheelToZoom(this.onZoom);

  ValueChanged<bool> onZoom;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position)) return false;
    result.add(BoxHitTestEntry(this, position));
    hitTestChildren(result, position: position);
    return true;
  }

  @override
  void handleEvent(PointerEvent event, HitTestEntry entry) {
    if (event is! PointerScrollEvent ||
        event.kind != PointerDeviceKind.mouse ||
        event.scrollDelta.dy == 0 ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (_) => onZoom(event.scrollDelta.dy < 0),
    );
  }
}
