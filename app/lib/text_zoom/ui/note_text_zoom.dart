import 'package:flutter/widgets.dart';

import '../text_zoom.dart';
import 'text_zoom_scale.dart';

/// [child], note text, at the note text zoom of [NoteTextZoomScope]
/// instead of the app's.
class NoteTextZoom extends StatelessWidget {
  const NoteTextZoom({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TextZoomScale(zoom: NoteTextZoomScope.of(context), child: child);
}

/// Tells [NoteTextZoom]s below it the note text zoom.
class NoteTextZoomScope extends InheritedWidget {
  const NoteTextZoomScope({
    required this.zoom,
    required super.child,
    super.key,
  });

  final TextZoom zoom;

  /// The note text zoom; [TextZoom.normal] outside any scope.
  static TextZoom of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NoteTextZoomScope>()?.zoom ??
      TextZoom.normal;

  @override
  bool updateShouldNotify(NoteTextZoomScope oldWidget) =>
      oldWidget.zoom != zoom;
}
