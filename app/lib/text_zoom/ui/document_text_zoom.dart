import 'package:flutter/widgets.dart';

import '../text_zoom.dart';
import 'text_zoom_scale.dart';

/// [child], document text, at the document text zoom of [DocumentTextZoomScope]
/// instead of the app's.
class DocumentTextZoom extends StatelessWidget {
  const DocumentTextZoom({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TextZoomScale(zoom: DocumentTextZoomScope.of(context), child: child);
}

/// Tells [DocumentTextZoom]s below it the document text zoom.
class DocumentTextZoomScope extends InheritedWidget {
  const DocumentTextZoomScope({
    required this.zoom,
    required super.child,
    super.key,
  });

  final TextZoom zoom;

  /// The document text zoom; [TextZoom.normal] outside any scope.
  static TextZoom of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DocumentTextZoomScope>()
          ?.zoom ??
      TextZoom.normal;

  @override
  bool updateShouldNotify(DocumentTextZoomScope oldWidget) =>
      oldWidget.zoom != zoom;
}
