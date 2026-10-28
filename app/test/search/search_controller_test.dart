import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/search/search_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = tempFolder();
    for (final (name, text) in [
      ('groceries/list.md', '# Shopping\n- milk\n- eggs'),
      ('plan.md', '# Plan\nbuy milk later'),
      ('ideas.txt', 'Ideas\nnothing to buy'),
    ]) {
      File('${dir.path}/$name').writeCreatingFolders(text);
    }
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await container.read(folderListStoreProvider).save([folderAt(dir)]);
    await container.read(folderContentsProvider.future);
  });

  /// Opens search and waits until it read every text.
  Future<DocumentSearchController> open() async {
    final shown = container.listen(searchProvider, (_, _) {});
    await eventually(() => shown.read().complete);
    return container.read(searchProvider.notifier);
  }

  List<String> found() => [
    for (final document in container.read(searchProvider).found)
      document.path.value,
  ];

  test('finds by title first, then by text', () async {
    final search = await open();

    search.find('shopping milk');
    expect(found(), ['groceries/list.md']);

    search.find('plan');
    expect(found(), ['plan.md']);

    search.find('buy');
    expect(found(), unorderedEquals(['plan.md', 'ideas.txt']));
  });

  test('finds by file and folder names', () async {
    final search = await open();

    search.find('groceries');
    expect(found(), ['groceries/list.md']);

    search.find('Documents ideas');
    expect(found(), ['ideas.txt']);
  });

  test('finds a document only by every word', () async {
    final search = await open();

    search.find('milk eggs');

    expect(found(), ['groceries/list.md']);
  });

  test('finds nothing for an empty query', () async {
    final search = await open();

    search.find('  ');

    expect(found(), isEmpty);
  });

  test('keeps the texts read when it opened, while it is open', () async {
    final search = await open();
    File('${dir.path}/plan.md').writeAsStringSync('# Plan\nnothing');

    search.find('milk');

    expect(found(), contains('plan.md'));
  });

  test('reads the texts again when it opens again', () async {
    final first = container.listen(searchProvider, (_, _) {});
    await eventually(() => first.read().complete);
    first.close();
    await pumpEventQueue();
    File('${dir.path}/plan.md').writeAsStringSync('# Plan\nnothing');

    (await open()).find('milk');

    expect(found(), ['groceries/list.md']);
  });
}
