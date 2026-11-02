import 'dart:io';

import 'package:test/test.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late File file;
  late FileSettingsStore store;

  setUp(() {
    file = File('${tempFolder().path}/settings/file_settings.json');
    store = FileSettingsStore(file);
  });

  /// The settings loaded, without the times their files went missing.
  Future<Map<String, FileSettings>> loaded() async => {
    for (final MapEntry(:key, :value) in (await store.load()).entries)
      key: value.settings,
  };

  test('a store key names its document again', () {
    final key = (baseId: 'b1', path: path('a/b.md'));

    expect(FileSettingsStore.keyOf(FileSettingsStore.storeKey(key)), key);
    expect(FileSettingsStore.keyOf('no-path'), isNull);
  });

  test('loads nothing before the first save', () async {
    expect(await loaded(), isEmpty);
  });

  test('saves and loads settings', () async {
    final key = FileSettingsStore.storeKey((baseId: 'b1', path: path('a.md')));
    final settings = FileSettings(
      pinned: true,
      view: ViewSettings({
        'mode': 'markdown',
        'list': [1, 2],
      }),
    );

    await store.save({
      key: KeptFileSettings(settings),
      'f1/b.md': const KeptFileSettings(FileSettings()),
    });

    expect(await loaded(), {key: settings, 'f1/b.md': FileSettings()});
  });

  test('keeps the time a document went missing', () async {
    final kept = KeptFileSettings(
      const FileSettings(pinned: true),
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
      'b1/a.md': FileSettings(view: ViewSettings({'mode': 'visual'})),
      'b1/d.md': const FileSettings(pinned: true),
    });

    file.writeAsStringSync('not json');
    expect(await loaded(), isEmpty);
  });

  test('keeps the pin of settings saved before types kept a view', () async {
    file.writeCreatingFolders(
      '{"b1/a.md": {"mode": "visual", "pinned": true, "checked": "inPlace"}}',
    );

    expect(await loaded(), {'b1/a.md': const FileSettings(pinned: true)});
  });
}
