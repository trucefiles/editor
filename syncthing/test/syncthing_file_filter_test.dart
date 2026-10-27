import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  const filter = SyncthingFileFilter(
    DefaultFileFilter(SyncthingAdapter(), ExtensionFileTypeDetector.standard()),
  );

  bool includes(String file) => filter.includesPath(path(file));

  test('includes documents and their conflict copies', () {
    expect(includes('a.md'), isTrue);
    expect(includes('sub/b.md'), isTrue);
    expect(includes('a.sync-conflict-20261003-134809-ABCDEFG.md'), isTrue);
  });

  test("leaves out Syncthing's own files and every temp file", () {
    for (final file in [
      '.syncthing.a.md.tmp',
      '.syncthing.truce-0123abcd.tmp',
      '~syncthing~a.md.tmp',
      '.stfolder/x',
      '.stversions/a~20261003-134809.md',
      '.stversions/a.sync-conflict-20261003-134809-ABCDEFG.md',
    ]) {
      expect(includes(file), isFalse, reason: file);
    }
  });

  test('leaves out conflict copies of files it leaves out', () {
    expect(includes('a.sync-conflict-20261003-134809-ABCDEFG.txt'), isFalse);
    expect(includes('.a.sync-conflict-20261003-134809-ABCDEFG.md'), isFalse);
  });
}
