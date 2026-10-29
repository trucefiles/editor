import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';

void main() {
  test('counts what stayed before and after a change', () {
    expect(unchangedEnds([1, 2, 3, 4], [1, 9, 4]), (start: 1, end: 1));
  });

  test('counts everything at the start in an unchanged list', () {
    expect(unchangedEnds([1, 2], [1, 2]), (start: 2, end: 0));
  });

  test('counts no item twice', () {
    expect(unchangedEnds([1, 1], [1, 1, 1]), (start: 2, end: 0));
  });

  test('takes repeated items as gone at the end', () {
    expect(unchangedEnds([1, 2, 1, 2], [1, 2]), (start: 2, end: 0));
  });

  test('finds nothing in common between empty lists', () {
    expect(unchangedEnds(<int>[], <int>[]), (start: 0, end: 0));
  });
}
