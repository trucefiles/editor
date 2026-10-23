import 'package:flutter/foundation.dart';

/// How large all text in the app shows on this device, on top of the
/// system's own text scaling, in percent of its base size: a step of
/// [step] from [min] to [max].
@immutable
final class TextZoom {
  const TextZoom._(this.percent);

  /// The zoom closest to [percent], within the zooms there are.
  factory TextZoom.closestTo(num percent) =>
      TextZoom._((percent.clamp(min, max) / step).round() * step);

  /// The zoom [json] holds, if it is one; `null` otherwise.
  static TextZoom? fromJson(Object? json) => switch (json) {
    final int percent when percent >= min && percent <= max =>
      percent % step == 0 ? TextZoom._(percent) : null,
    _ => null,
  };

  static const min = 80;
  static const max = 200;
  static const step = 10;

  /// No zoom: the text at its base size.
  static const normal = TextZoom._(100);

  final int percent;

  /// How many times its base size the text shows.
  double get factor => percent / 100;

  /// One step larger, as large as there is at most.
  TextZoom get larger => TextZoom.closestTo(percent + step);

  /// One step smaller, as small as there is at least.
  TextZoom get smaller => TextZoom.closestTo(percent - step);

  int toJson() => percent;

  @override
  bool operator ==(Object other) =>
      other is TextZoom && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;

  @override
  String toString() => '$percent %';
}
