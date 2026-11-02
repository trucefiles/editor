import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late Directory dir;
  late FileDrafts drafts;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    dir = Directory('${tempFolder().path}/drafts');
    drafts = FileDrafts(dir);
  });

  FileDraft draft(String id, String text) =>
      FileDraft(id: id, path: path('a/b.md'), base: '# b\n', text: text);

  test('keeps, replaces and removes drafts', () async {
    expect(await drafts.keep(draft('1', 'one')), isTrue);
    expect(await drafts.keep(draft('1', 'two')), isTrue);

    final [kept] = await drafts.all(before: later);
    expect(
      (kept.id, kept.path, kept.base, kept.text),
      ('1', path('a/b.md'), '# b\n', 'two'),
    );

    await drafts.remove('1');
    expect(await drafts.all(before: later), isEmpty);
  });

  test("keeps a new document's new subfolder", () async {
    await drafts.keep(
      FileDraft(id: '1', path: path('new/b.md'), text: 'b', newSubfolder: true),
    );
    await drafts.keep(FileDraft(id: '2', path: path('b.md'), text: 'b'));

    final kept = {
      for (final draft in await drafts.all(before: later))
        draft.id: draft.newSubfolder,
    };
    expect(kept, {'1': true, '2': false});
  });

  test('a draft with a bad new-subfolder field is still read', () async {
    File('${dir.path}/1.json')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '{"path": "b.md", "text": "mine", "newSubfolder": 1}',
      );

    final [kept] = await drafts.all(before: later);
    expect((kept.text, kept.newSubfolder), ('mine', false));
  });

  test('keeps the last of two drafts written at once', () async {
    final both = await Future.wait([
      drafts.keep(draft('1', 'one')),
      drafts.keep(draft('1', 'two')),
    ]);

    expect(both, [true, true]);
    final [kept] = await drafts.all(before: later);
    expect(kept.text, 'two');
  });

  test('removes a draft after its write still running', () async {
    await Future.wait([drafts.keep(draft('1', 'one')), drafts.remove('1')]);

    expect(await drafts.all(before: later), isEmpty);
  });

  test("keeps a new document's draft, without a folder", () async {
    await drafts.keep(FileDraft(id: '1', path: path('Milk.md'), text: 'Milk'));

    final [kept] = await drafts.all(before: later);
    expect((kept.path, kept.base, kept.text), (path('Milk.md'), null, 'Milk'));
  });

  test('removes all drafts of the folder', () async {
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));

    await drafts.forget();

    expect(await drafts.all(before: later), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('keeps no draft once the folder is forgotten', () async {
    await drafts.forget();

    expect(await drafts.keep(draft('1', 'late')), isFalse);
    expect(dir.existsSync(), isFalse);
  });

  test('a draft written while forgetting goes too', () async {
    final writing = drafts.keep(draft('1', 'one'));
    await drafts.forget();

    await writing;
    expect(dir.existsSync(), isFalse);
  });

  test('removes nothing before the first draft', () async {
    await drafts.forget();

    expect(await drafts.all(before: later), isEmpty);
  });

  test('counts the drafts of the folder', () async {
    expect(await drafts.count(), 0);
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));

    expect(await drafts.count(), 2);
  });

  test('has none before the first draft', () async {
    expect(await drafts.all(before: later), isEmpty);
  });

  test('leaves out drafts written since a time', () async {
    final start = DateTime.now().subtract(const Duration(seconds: 5));
    await drafts.keep(draft('1', 'one'));

    expect(await drafts.all(before: start), isEmpty);
  });

  test('skips files it cannot read, and leaves them in place', () async {
    await drafts.keep(draft('1', 'one'));
    final broken = File('${dir.path}/2.json')..writeAsStringSync('{');
    File('${dir.path}/documents.txt').writeAsStringSync('');

    final all = await drafts.all(before: later);

    expect([for (final draft in all) draft.id], ['1']);
    expect(broken.existsSync(), isTrue);
  });
}
