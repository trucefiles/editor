import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/folders/folder_services.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/refresh/auto_refresh.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';

import '../support.dart';

void main() {
  late StreamController<RelPath> changes;
  late _CountingScans scans;
  late ProviderContainer container;

  /// Starts auto refresh for one folder whose changes come from [changes];
  /// none are looked for if [manual].
  Future<void> start({bool active = true, bool manual = false}) async {
    // Broadcast: a rebuild listens again.
    changes = StreamController<RelPath>.broadcast();
    scans = _CountingScans();
    final folder = folderAt(tempFolder());
    container = ProviderContainer(
      overrides: [
        foldersProvider.overrideWith(() => _FixedFolders([folder])),
        folderChangesProvider.overrideWith(
          (ref, location) async => manual ? null : _StreamChanges(changes),
        ),
        appActiveProvider.overrideWith(() => _FixedActivity(active)),
        folderScansProvider.overrideWith(() => scans),
      ],
    );
    addTearDown(container.dispose);
    container.listen(autoRefreshProvider, (_, _) {});
    await container.read(autoRefreshProvider.future);
  }

  Future<void> settle() => Future<void>.delayed(
    AutoRefresh.settleTime + const Duration(milliseconds: 100),
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
    await container.read(autoRefreshProvider.future);

    expect(changes.hasListener, isFalse);
  });

  test('rescans once when it starts looking again', () async {
    await start();
    final activity =
        container.read(appActiveProvider.notifier) as _FixedActivity
          ..set(active: false);
    await container.read(autoRefreshProvider.future);

    activity.set(active: true);
    await container.read(autoRefreshProvider.future);
    await settle();

    expect(scans.refreshes, 1);
  });
}

final class _StreamChanges implements FolderChanges {
  _StreamChanges(this._controller);

  final StreamController<RelPath> _controller;

  @override
  Stream<RelPath> get changes => _controller.stream;
}

class _FixedFolders extends FoldersController {
  _FixedFolders(this._folders);

  final List<NoteFolder> _folders;

  @override
  Future<List<NoteFolder>> build() async => _folders;
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
    startedAt: DateTime(2026),
  );

  @override
  Future<void> refresh() async => refreshes++;
}
