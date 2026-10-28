import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import 'own_paste.dart';

/// The touch controls of the super_editor [child] (caret handles, the
/// drag handles of a selection, the toolbar) in [color], whichever touch
/// platform's controls the editor shows. The toolbar runs [operations]
/// (e.g. our own paste).
class TouchControls extends StatefulWidget {
  const TouchControls({
    required this.color,
    required this.operations,
    required this.child,
    super.key,
  });

  final Color color;
  final PasteOperations operations;
  final Widget child;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  late var _android = _androidIn(widget.color);
  late var _ios = _iosIn(widget.color);

  SuperEditorAndroidControlsController _androidIn(Color color) {
    late final SuperEditorAndroidControlsController controller;
    return controller = SuperEditorAndroidControlsController(
      controlsColor: color,
      toolbarBuilder: (context, key, focalPoint) => DefaultAndroidEditorToolbar(
        floatingToolbarKey: key,
        focalPoint: focalPoint,
        editorOps: widget.operations,
        editorControlsController: controller,
        selectionNotifier: widget.operations.selection,
      ),
    );
  }

  SuperEditorIosControlsController _iosIn(Color color) {
    late final SuperEditorIosControlsController controller;
    return controller = SuperEditorIosControlsController(
      handleColor: color,
      toolbarBuilder: (context, key, focalPoint) =>
          iOSSystemPopoverEditorToolbarWithFallbackBuilder(
            context,
            key,
            focalPoint,
            widget.operations,
            controller,
          ),
    );
  }

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
