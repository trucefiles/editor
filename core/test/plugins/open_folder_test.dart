import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('files show neither in a hidden folder nor where the app keeps '
      'files apart', () {
    final raw = FakeFolder();
    final open = raw.open(
      BoundedPlace(
        raw.files,
        raw.changes,
        bounds: FileBounds(
          handles: (file) => file.name.endsWith('.md'),
          keptApart: (path) => path.isAtOrInside(RelPath.parse('kept')!),
        ),
        checkEvery: () => const Duration(minutes: 1),
      ),
    );

    expect(open.showsFolder(path('notes')), isTrue);
    expect(open.showsFolder(path('notes/kept')), isTrue);
    expect(open.showsFolder(path('.hidden')), isFalse);
    expect(open.showsFolder(path('kept')), isFalse);
    expect(open.showsFolder(path('kept/inside')), isFalse);
  });
}
