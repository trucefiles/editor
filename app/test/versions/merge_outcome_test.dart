import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/versions/merge_outcome.dart';

void main() {
  test('nothing lost: says so', () {
    expect(mergeOutcome(const []), 'Merged. No changes were lost.');
  });

  test('a few lost: all named', () {
    expect(
      mergeOutcome(const ['Dentist', 'Swim']),
      'Merged. Some conflicts were resolved automatically; the overwritten '
      'changes are in '
      'Backups: "Dentist", "Swim".',
    );
  });

  test('many lost: the first three named, the rest counted', () {
    expect(
      mergeOutcome(List.generate(20, (index) => 'E${index + 1}')),
      contains('"E1", "E2", "E3" and 17 more.'),
    );
  });
}
