import 'package:collection/collection.dart';
import 'package:diffutil_dart/diffutil.dart';
import 'package:test/test.dart';

/// What `compareLines` relies on in diffutil beyond its docs: without
/// moves, its edit script runs from the end of the old list to its
/// start, so every position is one in the old list; at a change, the
/// removals come before the additions at the same place.
void main() {
  /// Two versions with changes in several places; [lines] each.
  (List<String>, List<String>) versions(int lines) => (
    [for (final i in Iterable<int>.generate(lines)) 'line $i'],
    [
      for (final i in Iterable<int>.generate(lines))
        if (i % 7 != 3) i % 5 == 0 ? 'changed $i' : 'line $i',
      'added at the end',
    ],
  );

  // Over 500 lines in all, diffutil finds matches another way.
  for (final lines in [20, 600]) {
    test('runs from the end, positions in the old list ($lines lines)', () {
      final (old, updated) = versions(lines);
      final script = calculateListDiff(
        old,
        updated,
        detectMoves: false,
      ).getUpdatesWithData().toList();

      expect(script, isNotEmpty);
      for (final update in script) {
        expect(
          update,
          anyOf(isA<DataRemove<String>>(), isA<DataInsert<String>>()),
        );
        if (update case DataRemove(:final position, :final data)) {
          expect(data, old[position]);
        }
      }
      for (final [before, after] in IterableZip([script, script.skip(1)])) {
        expect(
          after.position < before.position ||
              (after.position == before.position && after is DataInsert),
          isTrue,
          reason: '$before then $after',
        );
      }
    });
  }
}

extension on DataDiffUpdate<String> {
  int get position => switch (this) {
    DataInsert(:final position) || DataRemove(:final position) => position,
    DataChange(:final position) => position,
    DataMove(:final from) => from,
  };
}
