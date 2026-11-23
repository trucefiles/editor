import 'package:flutter/widgets.dart';

/// Where a double tap at [spot] takes a view: back to fit
/// ([Matrix4.identity]) if it is [zoomedIn], else [zoom] times in with
/// [spot] staying where it is.
///
/// `photo_view` and `extended_image` were checked for this: the first
/// zooms in on the middle, not on the tapped spot, and is no longer kept
/// up; the second leaves the zoom on a double tap to its user too, and
/// would replace the whole image view. So this small own step stays on
/// Flutter's `InteractiveViewer`.
Matrix4 tapZoomed({
  required bool zoomedIn,
  required Offset spot,
  required double zoom,
}) => zoomedIn
    ? Matrix4.identity()
    : (Matrix4.identity()
        ..translateByDouble(spot.dx, spot.dy, 0, 1)
        ..scaleByDouble(zoom, zoom, 1, 1)
        ..translateByDouble(-spot.dx, -spot.dy, 0, 1));
