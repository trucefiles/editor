import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// [view] filling the space, with [notes] (banners, the file's place)
/// over its top; [view]'s top padding says how far they cover it, so it
/// can let its content move out from under them.
class ViewUnderNotes extends StatefulWidget {
  const ViewUnderNotes({required this.notes, required this.view, super.key});

  final Widget notes;
  final Widget view;

  @override
  State<ViewUnderNotes> createState() => _ViewUnderNotesState();
}

class _ViewUnderNotesState extends State<ViewUnderNotes> {
  /// How tall [ViewUnderNotes.notes] are.
  double _covered = 0;

  void _notesAre(double height) {
    if (mounted && height != _covered) setState(() => _covered = height);
  }

  @override
  Widget build(BuildContext context) {
    final around = MediaQuery.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: MediaQuery(
            data: around.copyWith(
              padding: around.padding.copyWith(
                top: around.padding.top + _covered,
              ),
            ),
            child: widget.view,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _HeightReporter(onHeight: _notesAre, child: widget.notes),
        ),
      ],
    );
  }
}

/// Tells [onHeight] [child]'s height whenever a layout changes it, in
/// the next frame: a layout can't rebuild what it lays out.
class _HeightReporter extends SingleChildRenderObjectWidget {
  const _HeightReporter({required this.onHeight, required super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeightReporter(onHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHeightReporter renderObject,
  ) => renderObject.onHeight = onHeight;
}

class _RenderHeightReporter extends RenderProxyBox {
  _RenderHeightReporter(this.onHeight);

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
