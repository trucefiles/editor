import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/base_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/base_folder_following.dart';

import '../support.dart';

/// The app's providers with one folder showing [selection] of the base
/// folder at [basePath], and [refresh] set.
Future<({ProviderContainer container, BaseFolder base})> _start(
  String basePath,
  RefreshSettings refresh, {
  Selection selection = const WholeFolder(),
}) async {
  final container = ProviderContainer(
    overrides: [
      appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
      deviceIdProvider.overrideWithValue('0123456789abcdef'),
    ],
  );
  addTearDown(container.dispose);
  final folder = folderAt(Directory(basePath), selection: selection);
  await container.read(folderListStoreProvider).save([folder]);
  await container.read(refreshSettingsStoreProvider).save(refresh);
  await container.read(foldersProvider.future);
  container.listen(folderFollowingProvider(folder.base), (_, _) {});
  return (container: container, base: folder.base);
}

/// How changes to the base folder at [basePath] are followed.
Future<FolderFollowing> _following(
  String basePath,
  RefreshSettings refresh, {
  Selection selection = const WholeFolder(),
}) async {
  final (:container, :base) = await _start(
    basePath,
    refresh,
    selection: selection,
  );
  return container.read(folderFollowingProvider(base).future);
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

    test('watched, follow only the chosen subfolders', () async {
      final folder = tempFolder();
      Directory('${folder.path}/work').createSync();
      Directory('${folder.path}/home').createSync();
      final changes = (await _following(
        folder.path,
        live,
        selection: Selection.of([path('work')]),
      )).changes!;
      final seen = <RelPath>{};
      final subscription = changes.changes.listen(
        (hint) => seen.addAll(_pathOf(hint)),
      );
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      File('${folder.path}/home/a.md').writeAsStringSync('a');
      File('${folder.path}/top.md').writeAsStringSync('a');
      File('${folder.path}/work/a.md').writeAsStringSync('a');
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(seen, {path('work/a.md')});
    });
  });

  group('notices', () {
    Future<List<FolderNotice>> noticesOf(
      String path,
      RefreshSettings refresh,
    ) async {
      final (:container, :base) = await _start(path, refresh);
      return container.read(folderNoticesProvider(base).future);
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
      final (:container, :base) = await _start(folder.path, live);
      final following = await container.read(
        folderFollowingProvider(base).future,
      );
      final subscription = following.changes!.changes.listen((_) {});
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // Watching ends with the folder; it heals on its own once it is back.
      folder.deleteSync(recursive: true);
      addTearDown(folder.createSync);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        (await container.refresh(folderNoticesProvider(base).future))
            .whereType<PolledNotice>(),
        isEmpty,
      );
    }, testOn: 'linux');

    test('a gone chosen subfolder is followed live again once back', () async {
      final folder = tempFolder();
      Directory('${folder.path}/work').createSync();
      Directory('${folder.path}/home').createSync();
      final (:container, :base) = await _start(
        folder.path,
        live.copyWith(interval: const Duration(seconds: 5)),
        selection: Selection.of([path('work'), path('home')]),
      );
      final changes = (await container.read(
        folderFollowingProvider(base).future,
      )).changes!;
      final seen = <ChangeHint>[];
      final subscription = changes.changes.listen(seen.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      Directory('${folder.path}/work').deleteSync();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      File('${folder.path}/home/b.md').writeAsStringSync('b');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        seen,
        containsAllInOrder([const ListAgain(), PathChanged(path('home/b.md'))]),
      );

      // Checked again after the refresh interval.
      Directory('${folder.path}/work').createSync();
      await eventually(() async {
        File('${folder.path}/work/a.md').writeAsStringSync('a');
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return seen.contains(PathChanged(path('work/a.md')));
      });
    }, testOn: 'linux');
  });
}

/// The path [hint] names, if any.
List<RelPath> _pathOf(ChangeHint hint) => switch (hint) {
  PathChanged(:final path) => [path],
  ListAgain() => const [],
};
