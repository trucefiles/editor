import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../text_zoom.dart';

/// The keys that change the zoom, each with the zoom it makes of the
/// current one: Ctrl with + or = larger (layouts put + with or without
/// Shift), Ctrl+- smaller, Ctrl+0 no zoom.
final Map<SingleActivator, TextZoom Function(TextZoom zoom)> textZoomKeys = {
  for (final key in _larger) key: (zoom) => zoom.larger,
  for (final key in _smaller) key: (zoom) => zoom.smaller,
  for (final key in _normal) key: (_) => TextZoom.normal,
};

const _larger = [
  SingleActivator(LogicalKeyboardKey.equal, control: true),
  SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true),
  SingleActivator(LogicalKeyboardKey.add, control: true),
  SingleActivator(LogicalKeyboardKey.add, control: true, shift: true),
  SingleActivator(LogicalKeyboardKey.numpadAdd, control: true),
];
const _smaller = [
  SingleActivator(LogicalKeyboardKey.minus, control: true),
  SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true),
];
const _normal = [
  SingleActivator(LogicalKeyboardKey.digit0, control: true),
  SingleActivator(LogicalKeyboardKey.numpad0, control: true),
];
