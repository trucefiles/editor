import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/quick/quick_note_draft.dart';

import '../../support.dart';

void main() {
  late File file;
  late QuickNoteDrafts drafts;

  setUp(() {
    file = File('${tempFolder().path}/quick_note/draft.json');
    drafts = QuickNoteDrafts(file);
  });

  test('has none before the first keep', () async {
    expect(await drafts.load(), isNull);
  });

  test('keeps the text and the picked place', () async {
    final draft = QuickNoteDraft(
      text: 'Milk\n',
      place: (folderId: 'f1', subfolder: path('inbox')),
    );

    expect(await drafts.keep(draft), isTrue);

    expect(await drafts.load(), draft);
  });

  test('keeps a draft with no place picked', () async {
    await drafts.keep(const QuickNoteDraft(text: 'Milk'));

    expect(await drafts.load(), const QuickNoteDraft(text: 'Milk'));
  });

  test('remove drops it', () async {
    await drafts.keep(const QuickNoteDraft(text: 'Milk'));

    expect(await drafts.remove(), isTrue);

    expect(await drafts.load(), isNull);
  });

  test('a damaged file holds no draft', () async {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"text": 1}');

    expect(await drafts.load(), isNull);
  });
}
