import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final work = Selection.of([path('work'), path('home/notes')]);

  test('the whole folder covers and reaches everything', () {
    const whole = WholeFolder();

    expect(whole.covers(path('a/b.md')), isTrue);
    expect(whole.reaches(path('a')), isTrue);
  });

  test('subfolders cover what is inside them, nothing else', () {
    expect(work.covers(path('work')), isTrue);
    expect(work.covers(path('work/a/b.md')), isTrue);
    expect(work.covers(path('home/notes/a.md')), isTrue);
    expect(work.covers(path('home/a.md')), isFalse);
    expect(work.covers(path('workshop/a.md')), isFalse);
    expect(work.covers(path('a.md')), isFalse);
  });

  test('subfolders reach the folders on the way to them', () {
    expect(work.reaches(path('home')), isTrue);
    expect(work.reaches(path('home/notes/x')), isTrue);
    expect(work.reaches(path('home/other')), isFalse);
    expect(work.reaches(path('other')), isFalse);
  });

  test('a subfolder inside another adds nothing', () {
    expect(
      Selection.of([path('work'), path('work/a')]),
      Selection.of([path('work')]),
    );
  });

  test('overlap: the same subfolder or one inside the other', () {
    expect(work.overlaps(Selection.of([path('work/a')])), isTrue);
    expect(work.overlaps(Selection.of([path('home')])), isTrue);
    expect(work.overlaps(Selection.of([path('home/other')])), isFalse);
    expect(work.overlaps(const WholeFolder()), isTrue);
    expect(const WholeFolder().overlaps(Selection.nothing), isFalse);
  });

  test('union selects what either selects', () {
    final union = work.union(Selection.of([path('other'), path('work/a')]));

    expect(
      union,
      Selection.of([path('work'), path('home/notes'), path('other')]),
    );
    expect(work.union(const WholeFolder()), const WholeFolder());
  });

  test('nothing covers and reaches nothing', () {
    expect(Selection.nothing.covers(path('a.md')), isFalse);
    expect(Selection.nothing.reaches(path('a')), isFalse);
  });
}
