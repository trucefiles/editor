import 'package:truce_core/truce_core.dart';

/// A [TextMerge] over texts of `key:value` lines, one unit per key: a key
/// on one side only is kept, and on both sides the greater value wins (as
/// a newer edit would). Order: `main`'s lines, then `other`'s new ones.
/// A line without `:` can't be merged. [lost] names the keys of `other`
/// that lost, where `other` changed them from `base`.
final class FakeTextMerge implements TextMerge {
  const FakeTextMerge();

  @override
  MergeResult merge(String main, String other, {String? base}) {
    final (mains, others, bases) = (
      _units(main),
      _units(other),
      _units(base ?? ''),
    );
    if (mains == null || others == null) return const CantMerge();
    String winner(String key) => switch ((mains[key], others[key])) {
      (final a?, final b?) => a.compareTo(b) >= 0 ? a : b,
      (final a?, null) => a,
      (null, final b?) => b,
      (null, null) => throw StateError('no unit $key'),
    };
    final keys = {...mains.keys, ...others.keys};
    return MergedText(
      [for (final key in keys) '$key:${winner(key)}\n'].join(),
      lost: [
        for (final MapEntry(:key, :value) in others.entries)
          if (winner(key) != value && bases?[key] != value) key,
      ],
    );
  }

  /// The units of [text] by key, in order; `null` if it has a line that is
  /// no unit.
  static Map<String, String>? _units(String text) {
    final units = <String, String>{};
    for (final line in splitLines(text).where((line) => line.isNotEmpty)) {
      final colon = line.indexOf(':');
      if (colon < 0) return null;
      units[line.substring(0, colon)] = line.substring(colon + 1);
    }
    return units;
  }
}
