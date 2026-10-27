import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/add_item_place/add_item_place.dart';
import 'package:truce_editor/editor/add_item_place/add_item_place_controller.dart';
import 'package:truce_editor/editor/add_item_place/add_item_place_store.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

void main() {
  group('store', () {
    late File file;
    late AddItemPlaceStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/add_items.json');
      store = AddItemPlaceStore(file);
    });

    test('is at the top until the user chooses the bottom', () async {
      expect(await store.load(), AddItemPlace.top);
    });

    test('keeps the place', () async {
      await store.save(AddItemPlace.bottom);
      expect(await store.load(), AddItemPlace.bottom);

      await store.save(AddItemPlace.top);
      expect(await store.load(), AddItemPlace.top);
    });

    test('falls back to the top for an unreadable file', () async {
      file.writeCreatingFolders('{not json');

      expect(await store.load(), AddItemPlace.top);
    });
  });

  test('remembers the place across starts', () async {
    final storage = AppStorage(tempFolder().path);
    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [appStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    final first = container();
    await first.read(addItemPlaceProvider.notifier).set(AddItemPlace.bottom);
    expect(first.read(addItemPlaceProvider).value, AddItemPlace.bottom);
    first.dispose();

    expect(
      await container().read(addItemPlaceProvider.future),
      AddItemPlace.bottom,
    );
  });
}
