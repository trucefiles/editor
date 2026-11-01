import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/versions/merge_outcome.dart';

void main() {
  test('nothing lost: no clashes', () {
    expect(mergeOutcome(const []), 'Merged, no clashes.');
  });

  test('a few lost: all named', () {
    expect(
      mergeOutcome(const ['Dentist', 'Swim']),
      'Merged. Where both changed the same part, the newer change was '
      'kept: "Dentist", "Swim". The older versions are in Backups.',
    );
  });

  test('many lost: the first three named, the rest counted', () {
    expect(
      mergeOutcome(List.generate(20, (index) => 'E${index + 1}')),
      contains('"E1", "E2", "E3" and 17 more.'),
    );
  });
}
