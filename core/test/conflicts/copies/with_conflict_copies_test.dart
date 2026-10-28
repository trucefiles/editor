import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final filter = WithConflictCopies(
    VisibleFileFilter(const FakeSyncRules().isInternal),
    const FakeCopyNames(),
  );

  bool includes(String file) => filter.includesPath(path(file));

  test('includes documents and their conflict copies', () {
    expect(includes('a.md'), isTrue);
    expect(includes('sub/b.md'), isTrue);
    expect(includes('a.fake-copy-20261003-134809.md'), isTrue);
  });

  test("leaves out the sync tool's own files and every temp file", () {
    for (final file in [
      'a.md.fake-tmp',
      '.fake/x',
      '.fake/a.fake-copy-20261003-134809.md',
    ]) {
      expect(includes(file), isFalse, reason: file);
    }
  });

  test('leaves out conflict copies of files it leaves out', () {
    expect(includes('.a.fake-copy-20261003-134809.md'), isFalse);
  });
}
