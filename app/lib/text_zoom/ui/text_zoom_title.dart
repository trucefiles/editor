import '../text_zoom_target.dart';

/// The name of the zoom of [target], wherever it shows.
String textZoomTitle(TextZoomTarget target) => switch (target) {
  TextZoomTarget.documents => 'Document text size',
  TextZoomTarget.app => 'App text size',
};
