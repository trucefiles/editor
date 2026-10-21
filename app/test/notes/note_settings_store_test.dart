import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/checked_items.dart';
import 'package:truce_editor/editor/note_mode.dart';
import 'package:truce_editor/notes/kept_note_settings.dart';
import 'package:truce_editor/notes/note_settings.dart';
import 'package:truce_editor/notes/note_settings_store.dart';

import '../support.dart';

void main() {
  late File file;
  late NoteSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/note_views.json');
    store = NoteSettingsStore(file);
  });

  /// The settings loaded, without the times their notes went missing.
  Future<Map<String, NoteSettings>> loaded() async => {
    for (final MapEntry(:key, :value) in (await store.load()).entries)
      key: value.settings,
  };

  test('loads nothing before the first save', () async {
    expect(await loaded(), isEmpty);
  });

  test('saves and loads settings', () async {
    final key = NoteSettingsStore.storeKey((
      folderId: 'f1',
      path: path('a.md'),
    ));
    const settings = NoteSettings(
      mode: NoteMode.markdown,
      pinned: true,
      checkedItems: CheckedItems.toEnd,
    );

    await store.save({
      key: const KeptNoteSettings(settings),
      'f1/b.md': const KeptNoteSettings(NoteSettings()),
    });

    expect(await loaded(), {key: settings, 'f1/b.md': NoteSettings()});
  });

  test('keeps the time a note went missing', () async {
    final kept = KeptNoteSettings(
      const NoteSettings(pinned: true),
      missingSince: DateTime.utc(2026, 10, 21, 9),
    );

    await store.save({'f1/a.md': kept});

    expect(await store.load(), {'f1/a.md': kept});
  });

  test('reads the views older versions saved, as their modes', () async {
    file.writeCreatingFolders(
      '{"f1/a.md": "list", "f1/b.md": "text", '
      '"f1/c.md": {"view": "rendered", "pinned": true, "checked": "inPlace"}}',
    );

    expect(await loaded(), {
      'f1/a.md': const NoteSettings(mode: NoteMode.visual),
      'f1/b.md': const NoteSettings(mode: NoteMode.markdown),
      'f1/c.md': const NoteSettings(
        mode: NoteMode.read,
        pinned: true,
        checkedItems: CheckedItems.inPlace,
      ),
    });
  });

  test('reads the Done section older versions saved', () async {
    file.writeCreatingFolders(
      '{"f1/a.md": {"pinned": true, "doneSection": false}, '
      '"f1/b.md": {"pinned": false, "doneSection": true}}',
    );

    expect(await loaded(), {
      'f1/a.md': const NoteSettings(
        pinned: true,
        checkedItems: CheckedItems.inPlace,
      ),
      'f1/b.md': const NoteSettings(),
    });
  });

  test('ignores a damaged file and entries it cannot read', () async {
    file.writeCreatingFolders(
      '{"f1/a.md": "list", "f1/b.md": "grid", '
      '"f1/c.md": {"pinned": 1, "doneSection": true}, '
      '"f1/d.md": {"view": "grid", "pinned": true, "doneSection": true}}',
    );
    expect(await loaded(), {
      'f1/a.md': const NoteSettings(mode: NoteMode.visual),
      'f1/d.md': const NoteSettings(pinned: true),
    });

    file.writeAsStringSync('not json');
    expect(await loaded(), isEmpty);
  });
}
