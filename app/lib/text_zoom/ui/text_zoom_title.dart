import '../text_zoom_target.dart';

/// The name of the zoom of [target], wherever it shows.
String textZoomTitle(TextZoomTarget target) => switch (target) {
  TextZoomTarget.notes => 'Note text zoom',
  TextZoomTarget.app => 'App text size',
};
