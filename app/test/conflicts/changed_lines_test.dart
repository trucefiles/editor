import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/conflicts/changed_lines.dart';

void main() {
  test('marks lines the other side lacks', () {
    expect(changedLines(['a', 'b', 'c'], ['a', 'c', 'd']), {1});
  });

  test('ignores order', () {
    expect(changedLines(['b', 'a'], ['a', 'b']), isEmpty);
  });

  test('counts repeated lines', () {
    expect(changedLines(['a', 'a'], ['a']), {1});
  });
}
