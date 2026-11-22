import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tells [onHeight] [child]'s height whenever a layout changes it, in
/// the next frame: a layout can't rebuild what it lays out. For a place
/// that needs to know what something drawn over it covers.
class HeightReporter extends SingleChildRenderObjectWidget {
  const HeightReporter({
    required this.onHeight,
    required super.child,
    super.key,
  });

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

/// The render side of [HeightReporter].
class RenderHeightReporter extends RenderProxyBox {
  RenderHeightReporter(this.onHeight);

  ValueChanged<double> onHeight;
  double? _told;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _told) return;
    _told = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
