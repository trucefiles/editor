import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_editor/documents/document_settings_store.dart';
import 'package:truce_editor/documents/kept_document_settings.dart';
import 'package:truce_editor/documents/view_settings.dart';

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
      pinned: true,
      view: ViewSettings({
        'mode': 'markdown',
        'list': [1, 2],
      }),
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

  test('ignores a damaged file and entries it cannot read', () async {
    file.writeCreatingFolders(
      '{"b1/a.md": {"pinned": false, "view": {"mode": "visual"}}, '
      '"b1/b.md": "list", '
      '"b1/c.md": {"pinned": 1, "view": {}}, '
      '"b1/d.md": {"pinned": true, "view": "grid"}}',
    );
    expect(await loaded(), {
      'b1/a.md': const DocumentSettings(view: ViewSettings({'mode': 'visual'})),
      'b1/d.md': const DocumentSettings(pinned: true),
    });

    file.writeAsStringSync('not json');
    expect(await loaded(), isEmpty);
  });

  test('keeps the pin of settings saved before types kept a view', () async {
    file.writeCreatingFolders(
      '{"b1/a.md": {"mode": "visual", "pinned": true, "checked": "inPlace"}}',
    );

    expect(await loaded(), {'b1/a.md': const DocumentSettings(pinned: true)});
  });
}
