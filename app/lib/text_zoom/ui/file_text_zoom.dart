import 'package:flutter/widgets.dart';

import '../text_zoom.dart';
import 'text_zoom_scale.dart';

/// [child], the text of a file, at the file text zoom of [FileTextZoomScope]
/// instead of the app's.
class FileTextZoom extends StatelessWidget {
  const FileTextZoom({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      TextZoomScale(zoom: FileTextZoomScope.of(context), child: child);
}

/// Tells [FileTextZoom]s below it the file text zoom.
class FileTextZoomScope extends InheritedWidget {
  const FileTextZoomScope({
    required this.zoom,
    required super.child,
    super.key,
  });

  final TextZoom zoom;

  /// The file text zoom; [TextZoom.normal] outside any scope.
  static TextZoom of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FileTextZoomScope>()?.zoom ??
      TextZoom.normal;

  @override
  bool updateShouldNotify(FileTextZoomScope oldWidget) =>
      oldWidget.zoom != zoom;
}
