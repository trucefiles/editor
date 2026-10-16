import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/scan/auto_rescan.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  late StreamController<RelPath> changes;
  late _CountingScans scans;
  late ProviderContainer container;

  /// Starts auto refresh for one folder whose changes come from [changes];
  /// none are looked for if [manual]. With [folders], the folder list
  /// loads only once it completes, and the start does not wait for it.
  Future<void> start({
    bool active = true,
    bool manual = false,
    Completer<void>? folders,
  }) async {
    // Broadcast: a rebuild listens again.
    changes = StreamController<RelPath>.broadcast();
    scans = _CountingScans();
    final folder = folderAt(tempFolder());
    container = ProviderContainer(
      overrides: [
        foldersProvider.overrideWith(
          () => _FixedFolders([folder], loaded: folders?.future),
        ),
        folderChangesProvider.overrideWith(
          (ref, location) async => manual ? null : _StreamChanges(changes),
        ),
        appActiveProvider.overrideWith(() => _FixedActivity(active)),
        folderScansProvider.overrideWith(() => scans),
        refreshSettingsProvider.overrideWith(_FixedSettings.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(autoRescanProvider, (_, _) {});
    if (folders == null) await container.read(autoRescanProvider.future);
  }

  Future<void> settle() => Future<void>.delayed(
    AutoRescan.settleTime + const Duration(milliseconds: 100),
  );

  test('rescans once for changes that come close together', () async {
    await start();

    changes
      ..add(path('a.md'))
      ..add(path('b.md'))
      ..add(path('a.md'));
    await settle();

    expect(scans.refreshes, 1);
  });

  test('rescans again for a later change', () async {
    await start();
    changes.add(path('a.md'));
    await settle();

    changes.add(path('b.md'));
    await settle();

    expect(scans.refreshes, 2);
  });

  test('does not look for changes while the app is not in use', () async {
    await start(active: false);

    expect(changes.hasListener, isFalse);
  });

  test('does not look for changes when refreshing is manual', () async {
    await start(manual: true);

    expect(changes.hasListener, isFalse);
  });

  test('stops looking once the app is no longer in use', () async {
    await start();
    expect(changes.hasListener, isTrue);

    (container.read(appActiveProvider.notifier) as _FixedActivity).set(
      active: false,
    );
    await container.read(autoRescanProvider.future);

    expect(changes.hasListener, isFalse);
  });

  test('a start the app left meanwhile looks for no changes', () async {
    final folders = Completer<void>();
    await start(folders: folders);

    (container.read(appActiveProvider.notifier) as _FixedActivity).set(
      active: false,
    );
    await container.read(autoRescanProvider.future);
    folders.complete();
    await settle();

    expect(changes.hasListener, isFalse);
  });

  test('leaves catching up after a pause to the screens', () async {
    await start();
    final activity =
        container.read(appActiveProvider.notifier) as _FixedActivity
          ..set(active: false);
    await container.read(autoRescanProvider.future);

    activity.set(active: true);
    await container.read(autoRescanProvider.future);
    await settle();

    expect(scans.refreshes, 0);
    expect(changes.hasListener, isTrue);
  });

  test('rescans once when the refresh setting changes', () async {
    await start();

    (container.read(refreshSettingsProvider.notifier) as _FixedSettings).change(
      RefreshSettings.standard.copyWith(mode: RefreshMode.periodic),
    );
    await container.read(autoRescanProvider.future);

    expect(scans.refreshes, 1);
  });

  test(
    'rescans while changes keep coming, at the latest after a while',
    () async {
      await start();
      final until = DateTime.now().add(
        AutoRescan.maxWait + const Duration(milliseconds: 500),
      );

      while (DateTime.now().isBefore(until)) {
        changes.add(path('a.md'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      expect(scans.refreshes, 1);
    },
  );
}

final class _StreamChanges implements FolderChanges {
  _StreamChanges(this._controller);

  final StreamController<RelPath> _controller;

  @override
  Stream<RelPath> get changes => _controller.stream;
}

class _FixedFolders extends FoldersController {
  _FixedFolders(this._folders, {this._loaded});

  final List<NoteFolder> _folders;
  final Future<void>? _loaded;

  @override
  Future<List<NoteFolder>> build() async {
    await _loaded;
    return _folders;
  }
}

class _FixedSettings extends RefreshSettingsController {
  @override
  Future<RefreshSettings> build() async => RefreshSettings.standard;

  void change(RefreshSettings settings) => state = AsyncData(settings);
}

class _FixedActivity extends AppActivity {
  _FixedActivity(this._active);

  final bool _active;

  @override
  bool build() => _active;

  void set({required bool active}) => state = active;
}

class _CountingScans extends FolderScansController {
  int refreshes = 0;

  @override
  Future<FolderScans> build() async => FolderScans(
    notes: const [],
    marks: const {},
    subfolders: const {},
    conflicts: FolderConflicts(const []),
    failedFolders: const {},
    startedAt: Moment.now(),
  );

  @override
  Future<void> refresh() async => refreshes++;
}
