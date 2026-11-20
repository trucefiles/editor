import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  Draft draft(String id, String text, {DraftOf of = const OwnDraft('v1')}) =>
      Draft(DraftHead(id: id, path: path('a/b.md'), of: of), utf8.encode(text));

  Future<String?> contentOf(DraftHead head) async =>
      switch (await drafts.content(head)) {
        final bytes? => utf8.decode(bytes),
        null => null,
      };

  File fileOf(String id) => File('${dir.path}/$id.draft');

  test('keeps, replaces and removes drafts', () async {
    expect(await drafts.keep(draft('1', 'one')), isTrue);
    expect(await drafts.keep(draft('1', 'two')), isTrue);

    final [kept] = await drafts.heads(before: later);
    expect((kept.id, kept.path), ('1', path('a/b.md')));
    expect((kept.of as OwnDraft).part, 'v1');
    expect(await contentOf(kept), 'two');

    await drafts.remove('1');
    expect(await drafts.heads(before: later), isEmpty);
  });

  test("keeps a new file's new subfolder", () async {
    await drafts.keep(
      draft('1', 'b', of: const NewFileDraft(newSubfolder: true)),
    );
    await drafts.keep(draft('2', 'b', of: const NewFileDraft()));

    final kept = {
      for (final head in await drafts.heads(before: later))
        head.id: (head.of as NewFileDraft).newSubfolder,
    };
    expect(kept, {'1': true, '2': false});
  });

  test('keeps any bytes as they are', () async {
    final bytes = Uint8List.fromList([0, 10, 255, 10, 13, 0xEF, 0xBB]);
    await drafts.keep(
      Draft(
        DraftHead(id: '1', path: path('a.png'), of: const NewFileDraft()),
        bytes,
      ),
    );

    final [kept] = await drafts.heads(before: later);
    expect(await drafts.content(kept), bytes);
  });

  test('a draft with a bad new-subfolder field is still read', () async {
    fileOf('1')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'truce-draft 1\n{"path":"b.md","newSubfolder":1,"length":4}\nmine',
      );

    final [kept] = await drafts.heads(before: later);
    expect((kept.of as NewFileDraft).newSubfolder, isFalse);
    expect(await contentOf(kept), 'mine');
  });

  test('a cut off draft is no draft, and is left in place', () async {
    await drafts.keep(draft('1', 'whole'));
    final cut = fileOf('2')
      ..writeAsStringSync('truce-draft 1\n{"path":"b.md","length":9}\nhalf');

    final heads = await drafts.heads(before: later);

    expect([for (final head in heads) head.id], ['1']);
    expect(cut.existsSync(), isTrue);
    expect(await drafts.every(), isNull);
  });

  test('a draft that changed since it was listed is not read', () async {
    await drafts.keep(draft('1', 'one'));
    final [head] = await drafts.heads(before: later);
    fileOf('1').writeAsStringSync('broken');

    expect(await drafts.content(head), isNull);
  });

  test('keeps the last of two drafts written at once', () async {
    final both = await Future.wait<bool>([
      drafts.keep(draft('1', 'one')),
      drafts.keep(draft('1', 'two')),
    ]);

    expect(both, [true, true]);
    final [kept] = await drafts.heads(before: later);
    expect(await contentOf(kept), 'two');
  });

  test('removes a draft after its write still running', () async {
    await Future.wait<void>([
      drafts.keep(draft('1', 'one')),
      drafts.remove('1'),
    ]);

    expect(await drafts.heads(before: later), isEmpty);
  });

  test('removes all drafts of the folder', () async {
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));

    await drafts.forget();

    expect(await drafts.heads(before: later), isEmpty);
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

  test('gives every draft, or none if one can not be read', () async {
    expect(await drafts.every(), isEmpty);
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));
    expect(
      (await drafts.every())!.map((head) => head.id),
      unorderedEquals(['1', '2']),
    );

    fileOf('3').writeAsStringSync('{broken');

    expect(await drafts.every(), isNull);
  });

  test('counts the drafts of the folder', () async {
    expect(await drafts.count(), 0);
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));

    expect(await drafts.count(), 2);
  });

  test('has none before the first draft', () async {
    expect(await drafts.heads(before: later), isEmpty);
  });

  test('leaves out drafts written since a time', () async {
    final start = DateTime.now().subtract(const Duration(seconds: 5));
    await drafts.keep(draft('1', 'one'));

    expect(await drafts.heads(before: start), isEmpty);
  });

  test('leaves other files alone, older drafts too', () async {
    await drafts.keep(draft('1', 'one'));
    final older = File('${dir.path}/2.json')..writeAsStringSync('{}');
    File('${dir.path}/documents.txt').writeAsStringSync('');

    final heads = await drafts.heads(before: later);

    expect([for (final head in heads) head.id], ['1']);
    expect(older.existsSync(), isTrue);
  });

  test('removes temp files of writes cut off before the start', () async {
    await drafts.keep(draft('1', 'one'));
    final cutOff = File('${dir.path}/2.tmp')..writeAsStringSync('half');

    await drafts.heads(
      before: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(cutOff.existsSync(), isTrue);

    await drafts.heads(before: later);
    expect(cutOff.existsSync(), isFalse);
  });
}
