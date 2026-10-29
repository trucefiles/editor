import 'package:diffutil_dart/diffutil.dart';

import '../common/unchanged_ends.dart';

/// For each line of [updated], the line of [old] it is: the same lines at
/// the start and the end, and a line diff (diffutil) between them; `null`
/// for a line [old] doesn't have.
List<int?> oldLinesOf(List<String> old, List<String> updated) {
  final same = unchangedEnds(old, updated);
  final oldEnd = old.length - same.end;
  final middle = List<int?>.generate(
    oldEnd - same.start,
    (line) => same.start + line,
  );
  // The script turns the old middle into the new one, applied in order.
  final script = calculateListDiff(
    old.sublist(same.start, oldEnd),
    updated.sublist(same.start, updated.length - same.end),
    detectMoves: false,
  ).getUpdatesWithData();
  for (final update in script) {
    switch (update) {
      case DataRemove(:final position):
        middle.removeAt(position);
      case DataInsert(:final position):
        middle.insert(position, null);
      case DataChange() || DataMove():
        throw StateError('A list diff without moves has no changes or moves');
    }
  }
  return [
    ...List.generate(same.start, (line) => line),
    ...middle,
    ...List.generate(same.end, (line) => oldEnd + line),
  ];
}

/// For each line of [old], the line of [updated] it is, as [oldLinesOf]
/// matches them; `null` for a line [updated] doesn't keep.
List<int?> newLinesOf(List<String> old, List<String> updated) {
  final matched = {
    for (final (now, before) in oldLinesOf(old, updated).indexed) ?before: now,
  };
  return List.generate(old.length, (line) => matched[line]);
}
