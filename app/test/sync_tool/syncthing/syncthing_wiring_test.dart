import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/sync_tool/syncthing/syncthing_wiring.dart';

import '../../support.dart';

void main() {
  const live = RefreshSettings.standard;
  final manual = live.copyWith(mode: RefreshMode.manual);
  final periodic = live.copyWith(mode: RefreshMode.periodic);
  const portalFolder = '/run/user/1000/doc/1a2b3c/Documents';

  group('changes', () {
    test('none are looked for with manual refresh', () {
      expect(
        syncthingFolderFollowing(
          tempFolder().path,
          manual,
          hostFacts(),
          reach: _reach(),
        ).changes,
        isNull,
      );
    });

    test('are found with periodic and live refresh', () {
      expect(
        syncthingFolderFollowing(
          tempFolder().path,
          periodic,
          hostFacts(),
          reach: _reach(),
        ).changes,
        isNotNull,
      );
      expect(
        syncthingFolderFollowing(
          tempFolder().path,
          live,
          hostFacts(),
          reach: _reach(),
        ).changes,
        isNotNull,
      );
    });

    test('leave out Syncthing temp files', () async {
      final folder = tempFolder();
      final changes = syncthingFolderFollowing(
        folder.path,
        periodic.copyWith(interval: const Duration(milliseconds: 20)),
        hostFacts(),
        reach: _reach(),
      ).changes!;
      final seen = <RelPath>[];
      final subscription = changes.changes.listen(seen.add);
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      File('${folder.path}/.syncthing.a.md.tmp').writeAsStringSync('a');
      File('${folder.path}/a.md').writeAsStringSync('a');
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(seen, [path('a.md')]);
    });

    for (final (name, refresh) in [
      ('polled', periodic.copyWith(interval: const Duration(milliseconds: 20))),
      ('watched', live),
    ]) {
      test('$name, follow only documents, conflict copies and marks', () async {
        final folder = tempFolder();
        final changes = syncthingFolderFollowing(
          folder.path,
          refresh,
          hostFacts(),
          reach: _reach(),
        ).changes!;
        final seen = <RelPath>{};
        final subscription = changes.changes.listen(seen.add);
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
    }
  });

  group('notices', () {
    Future<List<FolderNotice>> noticesOf(
      String path,
      RefreshSettings refresh,
    ) => syncthingFolderFollowing(
      path,
      refresh,
      hostFacts(),
      reach: _reach(),
    ).notices.check();

    test('tell when live updates fall back to polling', () async {
      final notices = await noticesOf(portalFolder, live);

      expect(notices, contains(PolledNotice(live.interval)));
    });

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

    test('tell when watching failed and changes are polled', () async {
      final folder = tempFolder();
      final following = syncthingFolderFollowing(
        folder.path,
        live,
        hostFacts(),
        reach: _reach(),
      );
      final subscription = following.changes!.changes.listen((_) {});
      addTearDown(subscription.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(
        (await following.notices.check()).whereType<PolledNotice>(),
        isEmpty,
      );

      // Watching ends with the folder.
      folder.deleteSync(recursive: true);
      addTearDown(folder.createSync);
      await Future<void>.delayed(const Duration(milliseconds: 500));

      expect(
        await following.notices.check(),
        contains(PolledNotice(live.interval)),
      );
    }, testOn: 'linux');
  });
}

/// A reach no test looks at.
FolderReach _reach() => folderReach(LocalFileStore('/', (token) => token));
