import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_editor/documents/document_settings_store.dart';
import 'package:truce_editor/documents/kept_document_settings.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

import '../support.dart';

void main() {
  late File file;
  late DocumentSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/file_settings.json');
    store = DocumentSettingsStore(file);
  });

  /// The settings loaded, without the times their documents went missing.
  Future<Map<String, DocumentSettings>> loaded() async => {
    for (final MapEntry(:key, :value) in (await store.load()).entries)
      key: value.settings,
  };

  test('a store key names its document again', () {
    final key = (folderId: 'f1', path: path('a/b.md'));

    expect(
      DocumentSettingsStore.keyOf(DocumentSettingsStore.storeKey(key)),
      key,
    );
    expect(DocumentSettingsStore.keyOf('no-path'), isNull);
  });

  test('loads nothing before the first save', () async {
    expect(await loaded(), isEmpty);
  });

  test('saves and loads settings', () async {
    final key = DocumentSettingsStore.storeKey((
      folderId: 'f1',
      path: path('a.md'),
    ));
    const settings = DocumentSettings(
      mode: EditMode.markdown,
      pinned: true,
      checkedItems: CheckedItems.moveToEnd,
    );

    await store.save({
      key: const KeptNoteSettings(settings),
      'f1/b.md': const KeptNoteSettings(DocumentSettings()),
    });

    expect(await loaded(), {key: settings, 'f1/b.md': DocumentSettings()});
  });

  test('keeps the time a document went missing', () async {
    final kept = KeptNoteSettings(
      const DocumentSettings(pinned: true),
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
      'f1/a.md': const DocumentSettings(mode: EditMode.visual),
      'f1/b.md': const DocumentSettings(mode: EditMode.markdown),
      'f1/c.md': const DocumentSettings(
        mode: EditMode.read,
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
      'f1/a.md': const DocumentSettings(
        pinned: true,
        checkedItems: CheckedItems.inPlace,
      ),
      'f1/b.md': const DocumentSettings(checkedItems: CheckedItems.doneSection),
    });
  });

  test('reads Move to end as older versions named it', () async {
    file.writeCreatingFolders(
      '{"f1/a.md": {"pinned": false, "checked": "toEnd"}}',
    );

    expect(await loaded(), {
      'f1/a.md': const DocumentSettings(checkedItems: CheckedItems.moveToEnd),
    });
  });

  test('a document never set moves checked items to the end', () {
    expect(DocumentSettings.defaults.checkedItems, CheckedItems.moveToEnd);
  });

  test('ignores a damaged file and entries it cannot read', () async {
    file.writeCreatingFolders(
      '{"f1/a.md": "list", "f1/b.md": "grid", '
      '"f1/c.md": {"pinned": 1, "doneSection": true}, '
      '"f1/d.md": {"view": "grid", "pinned": true, "doneSection": true}}',
    );
    expect(await loaded(), {
      'f1/a.md': const DocumentSettings(mode: EditMode.visual),
      'f1/d.md': const DocumentSettings(
        pinned: true,
        checkedItems: CheckedItems.doneSection,
      ),
    });

    file.writeAsStringSync('not json');
    expect(await loaded(), isEmpty);
  });
}
