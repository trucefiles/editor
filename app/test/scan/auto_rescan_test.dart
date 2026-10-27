import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/reach/folder_reach_controller.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/scan/auto_rescan.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_editor/scan/folder_scans_controller.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';

import '../support.dart';

void main() {
  late StreamController<RelPath> changes;
  late _RecordingScans scans;
  late ProviderContainer container;
  late DocumentFolder folder;

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
    scans = _RecordingScans();
    folder = folderAt(tempFolder());
    container = ProviderContainer(
      overrides: [
        foldersProvider.overrideWith(
          () => _FixedFolders([folder], loaded: folders?.future),
        ),
        folderChangesProvider.overrideWith(
          (ref, location) async => manual ? null : _StreamChanges(changes),
        ),
        appActiveProvider.overrideWith(() => _FixedActivity(active)),
        folderScansOwnerProvider.overrideWithValue(scans),
        refreshSettingsProvider.overrideWith(_FixedSettings.new),
        folderReachProvider.overrideWith2(_SettableReach.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(autoRescanProvider, (_, _) {});
    if (folders == null) await container.read(autoRescanProvider.future);
  }

  Future<void> settle() => pumpEventQueue();

  test('follows a folder afresh once it is reachable again', () async {
    await start();
    var listens = 0;
    changes.onListen = () => listens++;
    final reach = container.read(
      folderReachProvider(folder.location).notifier,
    ) as _SettableReach;

    reach.set(Reach.unreachable);
    await container.read(autoRescanProvider.future);
    final before = listens;
    reach.set(Reach.reachable);
    await container.read(autoRescanProvider.future);

    expect(listens, before + 1);
  });

  test('tells the scans of every change', () async {
    await start();

    changes
      ..add(path('a.md'))
      ..add(path('b.md'));
    await settle();

    expect(
      scans.inputs.whereType<FilesChanged<Object?, Object?>>(),
      hasLength(2),
    );
  });

  test('tells the scans whether the app is in use', () async {
    await start();
    (container.read(appActiveProvider.notifier) as _FixedActivity).set(
      active: false,
    );
    await container.read(autoRescanProvider.future);

    expect(
      [
        for (final input in scans.inputs)
          if (input case Active(:final active)) active,
      ],
      [true, false],
    );
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

    expect(scans.inputs.whereType<FilesChanged<Object?, Object?>>(), isEmpty);
    expect(scans.inputs.whereType<SettingChanged<Object?, Object?>>(), isEmpty);
    expect(changes.hasListener, isTrue);
  });

  test('tells the scans once when the refresh setting changes', () async {
    await start();

    (container.read(refreshSettingsProvider.notifier) as _FixedSettings).show(
      RefreshSettings.standard.copyWith(mode: RefreshMode.periodic),
    );
    await container.read(autoRescanProvider.future);

    expect(
      scans.inputs.whereType<SettingChanged<Object?, Object?>>(),
      hasLength(1),
    );
  });
}

final class _StreamChanges implements FolderChanges {
  _StreamChanges(this._controller);

  final StreamController<RelPath> _controller;

  @override
  Stream<RelPath> get changes => _controller.stream;
}

class _FixedFolders extends FoldersController {
  _FixedFolders(this._folders, {this._loaded});

  final List<DocumentFolder> _folders;
  final Future<void>? _loaded;

  @override
  Future<List<DocumentFolder>> build() async {
    await _loaded;
    return _folders;
  }
}

class _FixedSettings extends RefreshSettingsController {
  @override
  Future<RefreshSettings> build() async => RefreshSettings.standard;

  void show(RefreshSettings settings) => state = AsyncData(settings);
}

class _FixedActivity extends AppActivity {
  _FixedActivity(this._active);

  final bool _active;

  @override
  bool build() => _active;

  void set({required bool active}) => state = active;
}

/// A scans owner that records what it is told.
final class _RecordingScans implements FolderScansOwner {
  final inputs = <ScansInput<DocumentFolder, FolderScans>>[];

  @override
  void send(ScansInput<DocumentFolder, FolderScans> input) => inputs.add(input);

  @override
  FolderScans? get state => null;

  @override
  Stream<FolderScans?> get changes => const Stream.empty();

  @override
  Stream<Fresh> get events => const Stream.empty();

  @override
  Future<void> close() async {}
}

/// One reach for every folder, set by the test.
class _SettableReach extends FolderReachController {
  _SettableReach(super.location);

  @override
  Reach build() => Reach.reachable;

  void set(Reach reach) => state = reach;
}
