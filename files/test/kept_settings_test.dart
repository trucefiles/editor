import 'package:test/test.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  final a = (folder: folderId('f1'), path: path('a.md'));
  final b = (folder: folderId('f1'), path: path('b.md'));
  const pinned = FileSettings(pinned: true);

  KeptSettings pinnedAll(List<FileKey> files) => {
    for (final file in files)
      FileSettingsStore.storeKey(file): const KeptFileSettings(pinned),
  };

  test('an edit keeps the changed settings, the others as they are', () {
    final all = editedIn(
      pinnedAll([b]),
      a,
      (settings) => settings.withPinned(pinned: true),
    );

    expect(all, pinnedAll([a, b]));
    expect(settingsIn(all, a), pinned);
  });

  test('settings changed back to the defaults are not kept', () {
    final all = editedIn(
      pinnedAll([a, b]),
      a,
      (settings) => settings.withPinned(pinned: false),
    );

    expect(all, pinnedAll([b]));
    expect(settingsIn(all, a), FileSettings.defaults);
  });

  test('forgetting a file drops only its settings', () {
    expect(forgottenIn(pinnedAll([a, b]), a), pinnedAll([b]));
  });

  test('a file without settings, or before they load, has the defaults', () {
    expect(settingsIn(const {}, a), FileSettings.defaults);
    expect(settingsIn(null, a), FileSettings.defaults);
  });
}
