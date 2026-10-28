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
    final key = (baseId: 'b1', path: path('a/b.md'));

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
      baseId: 'b1',
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

    await store.save({'b1/a.md': kept});

    expect(await store.load(), {'b1/a.md': kept});
  });

  test('a document never set moves checked items to the end', () {
    expect(DocumentSettings.defaults.checkedItems, CheckedItems.moveToEnd);
  });

  test('ignores a damaged file and entries it cannot read', () async {
    file.writeCreatingFolders(
      '{"b1/a.md": {"mode": "visual", "pinned": false, "checked": "inPlace"}, '
      '"b1/b.md": "list", '
      '"b1/c.md": {"pinned": 1, "checked": "inPlace"}, '
      '"b1/d.md": {"mode": "grid", "pinned": true, "checked": "doneSection"}, '
      '"b1/e.md": {"pinned": true, "checked": "sideways"}}',
    );
    expect(await loaded(), {
      'b1/a.md': const DocumentSettings(
        mode: EditMode.visual,
        checkedItems: CheckedItems.inPlace,
      ),
      'b1/d.md': const DocumentSettings(
        pinned: true,
        checkedItems: CheckedItems.doneSection,
      ),
    });

    file.writeAsStringSync('not json');
    expect(await loaded(), isEmpty);
  });
}
