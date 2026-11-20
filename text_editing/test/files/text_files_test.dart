import 'dart:convert';

import 'package:test/test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

final class _Type extends TextFileType {
  const _Type();

  @override
  FakeFileType get support => const FakeFileType();

  @override
  String get name => 'Fake';

  @override
  TextFile get newFile => const TextFile.empty();

  @override
  List<NewFileKind> get newKinds => const [NewFileKind('Note')];

  @override
  TextSummary<Object?> summary(String text, {required int maxLines}) =>
      throw UnimplementedError();

  @override
  String textSearchWords(FileText read) => read.text;

  @override
  FileCardSummary textCard(FileText read) => throw UnimplementedError();

  @override
  TextMerge? get textMerge => null;
}

void main() {
  late FakeFolder raw;
  late TextFiles files;

  setUp(() {
    final folder = Folder(
      id: folderId('f1'),
      name: 'Files',
      color: 'teal',
      location: 'fake:f1',
    );
    raw = FakePlugin().folder(folder.id.folder);
    final types = ShownFileTypes([const _Type()]);
    files = TextFiles(
      FilesOfFolder(
        folder,
        folderServices(
          raw,
          reach: folderReach(raw.files),
          handles: types.handles,
          keptApart: (_) => false,
          checkEvery: () => const Duration(seconds: 1),
          backupsPath: tempFolder().path,
          deviceId: '0123456789abcdef',
          wrote: (_) {},
        ),
        types,
      ),
    );
  });

  test('a file opens with its text, and a save keeps its byte style', () async {
    raw.files.put('a.md', 'a\r\nb');

    final opened = (await files.open(path('a.md'))).value;
    expect(opened.text, 'a\nb');

    await files.save(opened, 'a\nc');
    expect(raw.files.textOf('a.md'), 'a\r\nc');
  });

  test("a file's fingerprint is of its bytes, as in its file, also once "
      'written', () async {
    // As the fake store keeps it: one character per byte.
    const bytes = '\xEF\xBB\xBFa\r\nb\nc\r';
    raw.files.put('a.md', bytes);

    final opened = (await files.open(path('a.md'))).value;
    expect(opened.fingerprint, fingerprintOf(latin1.encode(bytes)));

    final saved = (await files.save(opened, 'a\nx\nc\n')).value;
    expect(
      saved.fingerprint,
      fingerprintOf(latin1.encode(raw.files.textOf('a.md')!)),
    );
    expect(saved.fingerprint, isNot(opened.fingerprint));
  });

  test('a file that is no text opens as NotText', () async {
    raw.files.put('a.md', 'ÿþ');

    expect((await files.open(path('a.md'))).error, isA<NotText>());
  });

  test('a file that is gone opens as not read', () async {
    expect(
      (await files.open(path('a.md'))).error,
      isA<NotRead>().having((e) => e.error, 'error', StoreError.notFound),
    );
  });

  test('a restored file keeps its byte style', () async {
    raw.files.put('a.md', 'a\r\nb');
    final opened = (await files.open(path('a.md'))).value;
    raw.files.files.remove(path('a.md'));

    await files.restore(opened, 'a\nc');
    expect(raw.files.textOf('a.md'), 'a\r\nc');
  });

  test('bytes the app wrote that are no text are a bug', () {
    expect(() => FileText.decodeWritten(bytesOf('ÿþ')), throwsStateError);
  });
}
