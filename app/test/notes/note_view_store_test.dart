import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_view.dart';
import 'package:truce_editor/notes/note_view_store.dart';

import '../support.dart';

void main() {
  late File file;
  late NoteViewStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/note_views.json');
    store = NoteViewStore(file);
  });

  test('loads nothing before the first save', () async {
    expect(await store.load(), isEmpty);
  });

  test('saves and loads views', () async {
    final key = NoteViewStore.storeKey((folderId: 'f1', path: path('a.md')));

    await store.save({key: NoteView.text});

    expect(await store.load(), {key: NoteView.text});
  });

  test('ignores a damaged file and unknown views', () async {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"f1/a.md": "list", "f1/b.md": "grid"}');
    expect(await store.load(), {'f1/a.md': NoteView.list});

    file.writeAsStringSync('not json');
    expect(await store.load(), isEmpty);
  });
}
