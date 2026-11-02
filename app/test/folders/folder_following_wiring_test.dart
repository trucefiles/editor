import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_folders/truce_folders.dart';

import '../support.dart';

/// The app's providers with one Syncthing folder [inside] the directory
/// at [rootPath] (all of it if `null`), and [refresh] set.
Future<({ProviderContainer container, FolderId folder})> _start(
  String rootPath,
  RefreshSettings refresh, {
  RelPath? inside,
}) async {
  final container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
      deviceIdProvider.overrideWithValue('0123456789abcdef'),
      loadedDeviceSettingsProvider.overrideWithValue(
        DeviceSettings.standard.copyWith(refresh: refresh),
      ),
    ],
  );
  addTearDown(container.dispose);
  final folder = await addSyncthingFolder(
    container,
    Directory(rootPath),
    inside: inside,
  );
  container.listen(folderFollowingProvider(folder.id), (_, _) {});
  return (container: container, folder: folder.id);
}

/// How changes to the folder [inside] the directory at [rootPath] are
/// followed.
Future<FolderFollowing> _following(
  String rootPath,
  RefreshSettings refresh, {
  RelPath? inside,
}) async {
  final (:container, :folder) = await _start(rootPath, refresh, inside: inside);
  return container.read(folderFollowingProvider(folder));
}

void main() {
  const live = RefreshSettings.standard;
  final manual = live.copyWith(mode: RefreshMode.manual);
  final periodic = live.copyWith(mode: RefreshMode.periodic);
  const portalFolder = '/run/user/1000/doc/1a2b3c/Documents';

  group('changes', () {
    test('none are looked for with manual refresh', () async {
      expect((await _following(tempFolder().path, manual)).changes, isNull);
    });

    test('are found with periodic and live refresh', () async {
      expect(
        (await _following(tempFolder().path, periodic)).changes,
        isNotNull,
      );
      expect((await _following(tempFolder().path, live)).changes, isNotNull);
    });

    test('leave out Syncthing temp files', () async {
      final folder = tempFolder();
      final changes = (await _following(folder.path, live)).changes!;
      final seen = <RelPath>[];
      final subscription = changes.changes.listen(
        (hint) => seen.addAll(_pathOf(hint)),
      );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      File('${folder.path}/.syncthing.a.md.tmp').writeAsStringSync('a');
      File('${folder.path}/a.md').writeAsStringSync('a');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(seen, [path('a.md')]);
    });

    // Polled changes ask for a listing, which keeps to the same files.
    test('watched, follow only documents, conflict copies and marks', () async {
      final folder = tempFolder();
      final changes = (await _following(folder.path, live)).changes!;
      final seen = <RelPath>{};
      final subscription = changes.changes.listen(
        (hint) => seen.addAll(_pathOf(hint)),
      );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      for (final file in [
        '.git/HEAD',
        '.obsidian/workspace.json',
        '.a.md.swp',
        'a.md~',
        'picture.png',
        'notes.txt',
        'sub/a.md',
        'a.sync-conflict-20261003-134809-ABCDEFG.md',
        '.truce/marks/laptop.json',
      ]) {
        File('${folder.path}/$file').writeCreatingFolders('a');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(seen, {
        path('notes.txt'),
        path('sub/a.md'),
        path('a.sync-conflict-20261003-134809-ABCDEFG.md'),
        path('.truce/marks/laptop.json'),
      });
    });

    test("watched, follow only the folder's own directory", () async {
      final root = tempFolder();
      Directory('${root.path}/work').createSync();
      Directory('${root.path}/home').createSync();
      final changes = (await _following(
        root.path,
        live,
        inside: path('work'),
      )).changes!;
      final seen = <RelPath>{};
      final subscription = changes.changes.listen(
        (hint) => seen.addAll(_pathOf(hint)),
      );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      File('${root.path}/home/a.md').writeAsStringSync('a');
      File('${root.path}/top.md').writeAsStringSync('a');
      File('${root.path}/work/a.md').writeAsStringSync('a');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(seen, {path('a.md')});
    });
  });

  group('notices', () {
    Future<List<FolderNotice>> noticesOf(
      String path,
      RefreshSettings refresh,
    ) async {
      final (:container, :folder) = await _start(path, refresh);
      return container.read(folderNoticesProvider(folder).future);
    }

    test(
      'tell when live updates can not work and changes are polled',
      () async {
        final notices = await noticesOf(portalFolder, live);

        expect(notices, contains(PolledNotice(live.interval)));
      },
    );

    test(
      'say nothing about polling unless live updates were asked for',
      () async {
        final notices = await noticesOf(portalFolder, periodic);

        expect(notices.whereType<PolledNotice>(), isEmpty);
      },
    );

    test('say nothing about polling where live updates work', () async {
      final notices = await noticesOf(tempFolder().path, live);

      expect(
        notices.whereType<PolledNotice>(),
        Platform.isLinux ? isEmpty : isNotEmpty,
      );
    });

    test('say nothing about polling once a watched folder is gone', () async {
      final folder = tempFolder();
      final (container: container, folder: id) = await _start(
        folder.path,
        live,
      );
      final following = container.read(folderFollowingProvider(id));
      final subscription = following.changes!.changes.listen((_) {});
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Watching ends with the folder; it heals on its own once it is back.
      folder.deleteSync(recursive: true);
      addTearDown(folder.createSync);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        (await container.refresh(folderNoticesProvider(id).future))
            .whereType<PolledNotice>(),
        isEmpty,
      );
    }, testOn: 'linux');

    test('a gone folder is followed live again once back', () async {
      final root = tempFolder();
      final work = Directory('${root.path}/work')..createSync();
      final (:container, :folder) = await _start(
        root.path,
        live.copyWith(interval: const Duration(seconds: 5)),
        inside: path('work'),
      );
      final changes = (container.read(folderFollowingProvider(folder)))
          .changes!;
      final seen = <ChangeHint>[];
      final subscription = changes.changes.listen(seen.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      work.deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(seen, contains(const ListAgain()));

      // Checked again after the refresh interval.
      work.createSync();
      await eventually(() async {
        File('${work.path}/a.md').writeAsStringSync('a');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return seen.contains(PathChanged(path('a.md')));
      });
    }, testOn: 'linux');
  });
}

/// The path [hint] names, if any.
List<RelPath> _pathOf(ChangeHint hint) => switch (hint) {
  PathChanged(:final path) => [path],
  ListAgain() => const [],
};
