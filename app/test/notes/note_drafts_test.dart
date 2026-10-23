import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_draft.dart';
import 'package:truce_editor/notes/note_drafts.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late NoteDrafts drafts;
  final later = DateTime.now().add(const Duration(days: 1));

  setUp(() {
    dir = Directory('${tempFolder().path}/drafts');
    drafts = NoteDrafts(dir);
  });

  NoteDraft draft(String id, String text) =>
      NoteDraft(id: id, path: path('a/b.md'), base: '# b\n', text: text);

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

  test("keeps a new note's draft, without a base", () async {
    await drafts.keep(NoteDraft(id: '1', path: path('Milk.md'), text: 'Milk'));

    final [kept] = await drafts.all(before: later);
    expect((kept.path, kept.base, kept.text), (path('Milk.md'), null, 'Milk'));
  });

  test('clears all drafts', () async {
    await drafts.keep(draft('1', 'one'));
    await drafts.keep(draft('2', 'two'));

    await drafts.clear();

    expect(await drafts.all(before: later), isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  test('clears nothing before the first draft', () async {
    await drafts.clear();

    expect(await drafts.all(before: later), isEmpty);
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
    File('${dir.path}/notes.txt').writeAsStringSync('');

    final all = await drafts.all(before: later);

    expect([for (final draft in all) draft.id], ['1']);
    expect(broken.existsSync(), isTrue);
  });
}
