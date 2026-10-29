import 'dart:math';

/// How many items [before] and [after] have equal at their [start], and
/// then at their [end], counting no item twice: what stayed around one
/// change. Where the change sits in repeated items (`abab` to `ab`) is a
/// guess: it is taken as gone at the end.
({int start, int end}) unchangedEnds<T>(List<T> before, List<T> after) {
  final shorter = min(before.length, after.length);
  final start = _sameCount(shorter, (index) => before[index] == after[index]);
  final end = _sameCount(
    shorter - start,
    (index) =>
        before[before.length - 1 - index] == after[after.length - 1 - index],
  );
  return (start: start, end: end);
}

/// How many of the first [count] indexes are [same], up to the first that
/// is not.
int _sameCount(int count, bool Function(int index) same) =>
    Iterable<int>.generate(count)
        .firstWhere((index) => !same(index), orElse: () => count);
