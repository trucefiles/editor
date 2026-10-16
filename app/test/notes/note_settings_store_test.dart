import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/notes/note_settings.dart';
import 'package:truce_editor/notes/note_settings_store.dart';
import 'package:truce_editor/notes/note_view.dart';

import '../support.dart';

void main() {
  late File file;
  late NoteSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/note_views.json');
    store = NoteSettingsStore(file);
  });

  test('loads nothing before the first save', () async {
    expect(await store.load(), isEmpty);
  });

  test('saves and loads settings', () async {
    final key = NoteSettingsStore.storeKey((
      folderId: 'f1',
      path: path('a.md'),
    ));
    const settings = NoteSettings(
      view: NoteView.text,
      pinned: true,
      doneSection: false,
    );

    await store.save({key: settings, 'f1/b.md': const NoteSettings()});

    expect(await store.load(), {key: settings, 'f1/b.md': NoteSettings()});
  });

  test('reads the views older versions saved', () async {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('{"f1/a.md": "list"}');

    expect(await store.load(), {
      'f1/a.md': const NoteSettings(view: NoteView.list),
    });
  });

  test('ignores a damaged file and entries it cannot read', () async {
    file
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(
        '{"f1/a.md": "list", "f1/b.md": "grid", '
        '"f1/c.md": {"pinned": 1, "doneSection": true}, '
        '"f1/d.md": {"view": "grid", "pinned": true, "doneSection": true}}',
      );
    expect(await store.load(), {
      'f1/a.md': const NoteSettings(view: NoteView.list),
      'f1/d.md': const NoteSettings(pinned: true),
    });

    file.writeAsStringSync('not json');
    expect(await store.load(), isEmpty);
  });
}
