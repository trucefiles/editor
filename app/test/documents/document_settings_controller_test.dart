import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_editor/documents/document_settings_controller.dart';
import 'package:truce_editor/documents/document_settings_store.dart';
import 'package:truce_editor/documents/kept_document_settings.dart';
import 'package:truce_editor/folder_state/folder_contents.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems, EditMode;

import '../support.dart';

void main() {
  late ProviderContainer container;
  late DocumentSettingsController views;
  final a = (baseId: 'f1', path: path('a.md'));
  final b = (baseId: 'f1', path: path('b.md'));

  setUp(() {
    final storage = AppStorage(tempFolder().path);
    container = ProviderContainer(
      overrides: [appStorageProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    views = container.read(documentSettingsProvider.notifier);
  });

  Future<Map<String, DocumentSettings>> saved() async => {
    for (final MapEntry(:key, :value)
        in (await container.read(documentSettingsStoreProvider).load()).entries)
      key: value.settings,
  };

  Future<void> remember(DocumentKey document, EditMode view) =>
      views.edit(document, (settings) => settings.withMode(view));

  EditMode? viewOf(DocumentKey document) => views.settingsOf(document).mode;

  test('views remembered at the same time are all kept', () async {
    await Future.wait([
      remember(a, EditMode.markdown),
      remember(b, EditMode.read),
    ]);

    final expected = {
      DocumentSettingsStore.storeKey(a): DocumentSettings(
        mode: EditMode.markdown,
      ),
      DocumentSettingsStore.storeKey(b): DocumentSettings(mode: EditMode.read),
    };
    expect(
      container.read(documentSettingsProvider).value,
      expected.map((key, value) => MapEntry(key, KeptNoteSettings(value))),
    );
    expect(await saved(), expected);
  });

  test('forget drops the view of a document', () async {
    await remember(a, EditMode.markdown);
    await remember(b, EditMode.read);

    await views.forget(a);

    expect(viewOf(a), isNull);
    expect(await saved(), {
      DocumentSettingsStore.storeKey(b): DocumentSettings(mode: EditMode.read),
    });
  });

  test('keeps pin and checked items with the view', () async {
    await remember(a, EditMode.visual);
    await views.edit(a, (settings) => settings.withPinned(pinned: true));
    await views.edit(
      a,
      (settings) => settings.withCheckedItems(CheckedItems.moveToEnd),
    );

    const expected = DocumentSettings(
      mode: EditMode.visual,
      pinned: true,
      checkedItems: CheckedItems.moveToEnd,
    );
    expect(views.settingsOf(a), expected);
    expect(await saved(), {DocumentSettingsStore.storeKey(a): expected});
  });

  test('drops settings changed back to the defaults', () async {
    await views.edit(a, (settings) => settings.withPinned(pinned: true));

    await views.edit(a, (settings) => settings.withPinned(pinned: false));

    expect(views.settingsOf(a), DocumentSettings.defaults);
    expect(await saved(), isEmpty);
  });

  group('prune', () {
    late DocumentFolder work;
    late DocumentFolder home;

    setUp(() {
      work = folderAt(tempFolder(), id: 'work', baseId: 'work');
      home = folderAt(tempFolder(), id: 'home', baseId: 'home');
    });

    final now = DateTime.utc(2026, 10, 21, 9);
    final graceLater = now.add(KeptNoteSettings.grace);

    Document documentAt(DocumentFolder folder, String name) =>
        listedDocument(folder, name: name);

    /// Prunes by [found] now and again once the grace period is over.
    Future<void> pruneAfterGrace(FolderContents found) async {
      await views.prune(found, now: now);
      await views.prune(found, now: graceLater);
    }

    FolderContents scans(
      List<Document> documents, {
      Map<DocumentFolder, StoreError> failed = const {},
      Map<String, List<RelPath>> unreadable = const {},
    }) => contentsFinding(
      documents,
      folders: [work, home],
      failed: failed,
      unreadable: unreadable,
    );

    test('drops views of documents and folders that are gone', () async {
      final kept = documentAt(work, 'kept.md');
      await remember(kept.key, EditMode.visual);
      await remember(documentAt(work, 'gone.md').key, EditMode.markdown);
      await remember((
        baseId: 'removed',
        path: path('a.md'),
      ), EditMode.markdown);

      await pruneAfterGrace(scans([kept]));

      expect(await saved(), {
        DocumentSettingsStore.storeKey(kept.key): DocumentSettings(
          mode: EditMode.visual,
        ),
      });
    });

    test('keeps the settings of a missing document for a while', () async {
      final gone = documentAt(work, 'gone.md');
      await views.edit(gone.key, (s) => s.withPinned(pinned: true));

      await views.prune(scans([]), now: now);
      await views.prune(
        scans([]),
        now: graceLater.subtract(const Duration(minutes: 1)),
      );

      expect(views.settingsOf(gone.key).pinned, isTrue);
    });

    test('a document found again starts its grace period anew', () async {
      final back = documentAt(work, 'back.md');
      await views.edit(back.key, (s) => s.withPinned(pinned: true));

      await views.prune(scans([]), now: now);
      await views.prune(scans([back]), now: now.add(const Duration(days: 1)));
      await views.prune(scans([]), now: now.add(const Duration(days: 2)));
      await views.prune(scans([]), now: graceLater);

      expect(views.settingsOf(back.key).pinned, isTrue);
    });

    test('keeps the time a document went missing across restarts', () async {
      final gone = documentAt(work, 'gone.md');
      await views.edit(gone.key, (s) => s.withPinned(pinned: true));
      await views.prune(scans([]), now: now);

      container.invalidate(documentSettingsProvider);
      views = container.read(documentSettingsProvider.notifier);
      await views.prune(scans([]), now: graceLater);

      expect(views.settingsOf(gone.key).pinned, isFalse);
    });

    test('keeps views of folders that could not be scanned', () async {
      final unread = documentAt(home, 'a.md');
      await remember(unread.key, EditMode.read);

      await pruneAfterGrace(scans([], failed: {home: StoreError.ioFailure}));

      expect(viewOf(unread.key), EditMode.read);
    });

    test('keeps the views of documents no folder shows', () async {
      final narrowed = work.copyWith(selection: Selection.of([path('kept')]));
      final outside = documentAt(work, 'elsewhere/a.md');
      await remember(outside.key, EditMode.read);

      await pruneAfterGrace(contentsFinding([], folders: [narrowed, home]));

      expect(viewOf(outside.key), EditMode.read);
    });

    test('keeps views below subfolders that could not be read', () async {
      final hidden = documentAt(work, 'private/a.md');
      final gone = documentAt(work, 'privateer.md');
      await remember(hidden.key, EditMode.read);
      await remember(gone.key, EditMode.markdown);

      await pruneAfterGrace(
        scans(
          [],
          unreadable: {
            work.id: [path('private')],
          },
        ),
      );

      expect(viewOf(hidden.key), EditMode.read);
      expect(viewOf(gone.key), isNull);
    });
  });
}
