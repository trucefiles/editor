import 'package:flutter/foundation.dart';

/// How large notes' text shows on this device, in percent of its base
/// size: a step of [step] from [min] to [max].
@immutable
final class NoteTextSize {
  const NoteTextSize._(this.percent);

  /// The size closest to [percent], within the sizes there are.
  factory NoteTextSize.closestTo(num percent) =>
      NoteTextSize._((percent.clamp(min, max) / step).round() * step);

  /// The size [json] holds, if it is one; `null` otherwise.
  static NoteTextSize? fromJson(Object? json) => switch (json) {
    final int percent when percent >= min && percent <= max =>
      percent % step == 0 ? NoteTextSize._(percent) : null,
    _ => null,
  };

  static const min = 80;
  static const max = 200;
  static const step = 10;

  /// The base size.
  static const normal = NoteTextSize._(100);

  final int percent;

  /// How many times its base size the text shows.
  double get factor => percent / 100;

  /// One step larger, as large as there is at most.
  NoteTextSize get larger => NoteTextSize.closestTo(percent + step);

  /// One step smaller, as small as there is at least.
  NoteTextSize get smaller => NoteTextSize.closestTo(percent - step);

  int toJson() => percent;

  @override
  bool operator ==(Object other) =>
      other is NoteTextSize && other.percent == percent;

  @override
  int get hashCode => percent.hashCode;

  @override
  String toString() => '$percent %';
}
