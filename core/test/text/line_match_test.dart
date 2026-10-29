import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('matches kept lines and leaves added ones out', () {
    expect(oldLinesOf(['a', 'b', 'c'], ['a', 'x', 'c', 'y']), [
      0,
      null,
      2,
      null,
    ]);
  });

  test('repeated lines at the start and end stay where they are', () {
    expect(oldLinesOf(['', '', 'a'], ['', '', '', 'a']), [0, 1, null, 2]);
  });

  test('tells the other way round where each old line went', () {
    expect(newLinesOf(['a', 'b', 'c'], ['x', 'a', 'c']), [1, null, 2]);
  });
}
