import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

/// The touch controls of the super_editor [child] (caret handles, the
/// drag handles of a selection) in [color], whichever touch platform's
/// controls the editor shows.
class TouchControls extends StatefulWidget {
  const TouchControls({required this.color, required this.child, super.key});

  final Color color;
  final Widget child;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  late var _android = _androidIn(widget.color);
  late var _ios = _iosIn(widget.color);

  static SuperEditorAndroidControlsController _androidIn(Color color) =>
      SuperEditorAndroidControlsController(controlsColor: color);

  static SuperEditorIosControlsController _iosIn(Color color) =>
      SuperEditorIosControlsController(handleColor: color);

  /// A color is set once per controller: a new color takes new ones.
  @override
  void didUpdateWidget(TouchControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.color == oldWidget.color) return;
    final (android, ios) = (_android, _ios);
    _android = _androidIn(widget.color);
    _ios = _iosIn(widget.color);
    // Once the editor has let go of them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      android.dispose();
      ios.dispose();
    });
  }

  @override
  void dispose() {
    _android.dispose();
    _ios.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SuperEditorAndroidControlsScope(
    controller: _android,
    child: SuperEditorIosControlsScope(controller: _ios, child: widget.child),
  );
}
