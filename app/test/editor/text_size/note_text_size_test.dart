import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/editor/text_size/note_text_size.dart';
import 'package:truce_editor/editor/text_size/note_text_size_controller.dart';
import 'package:truce_editor/editor/text_size/note_text_size_store.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

void main() {
  group('size', () {
    test('goes in steps from the smallest to the largest', () {
      expect(NoteTextSize.closestTo(114).percent, 110);
      expect(NoteTextSize.closestTo(116).percent, 120);
      expect(NoteTextSize.closestTo(10).percent, NoteTextSize.min);
      expect(NoteTextSize.closestTo(900).percent, NoteTextSize.max);
    });

    test('a step larger or smaller stops at the ends', () {
      expect(NoteTextSize.normal.larger.percent, 110);
      expect(NoteTextSize.normal.smaller.percent, 90);
      expect(NoteTextSize.closestTo(NoteTextSize.max).larger.percent, 200);
      expect(NoteTextSize.closestTo(NoteTextSize.min).smaller.percent, 80);
    });

    test('reads only the sizes there are', () {
      expect(NoteTextSize.fromJson(130)?.percent, 130);
      expect(NoteTextSize.fromJson(135), isNull);
      expect(NoteTextSize.fromJson(300), isNull);
      expect(NoteTextSize.fromJson('130'), isNull);
    });

    test('scales by its percent', () {
      expect(NoteTextSize.closestTo(150).factor, 1.5);
    });
  });

  group('store', () {
    late File file;
    late NoteTextSizeStore store;

    setUp(() {
      file = File('${tempFolder().path}/settings/note_text_size.json');
      store = NoteTextSizeStore(file);
    });

    test('is the base size until the user chooses another', () async {
      expect(await store.load(), NoteTextSize.normal);
    });

    test('keeps the size', () async {
      await store.save(NoteTextSize.closestTo(140));
      expect(await store.load(), NoteTextSize.closestTo(140));
    });

    test('falls back to the base size for an unreadable file', () async {
      file.writeCreatingFolders('{not json');
      expect(await store.load(), NoteTextSize.normal);
    });

    test('falls back to the base size for a size there is not', () async {
      file.writeCreatingFolders('{"percent": 999}');
      expect(await store.load(), NoteTextSize.normal);
    });
  });

  test('remembers the size across starts', () async {
    final storage = AppStorage(tempFolder().path);
    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [appStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      return container;
    }

    final first = container();
    await first
        .read(noteTextSizeProvider.notifier)
        .change((size) => size.larger);
    expect(first.read(noteTextSizeProvider).value?.percent, 110);

    expect(
      await container().read(noteTextSizeProvider.future),
      NoteTextSize.closestTo(110),
    );
  });
}
