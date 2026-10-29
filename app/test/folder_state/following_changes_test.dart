import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folder_state/following_changes.dart';
import 'package:truce_editor/folders/document_folder.dart';
import 'package:truce_editor/folders/folder_list_contract.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_activity.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/refresh/refresh_settings_controller.dart';
import 'package:truce_editor/sync_tool/base_folder_following.dart';

import '../support.dart';

void main() {
  late StreamController<ChangeHint> changes;
  late _RecordingOwner owner;
  late ProviderContainer container;
  late DocumentFolder folder;

  /// Starts following the changes of one folder whose changes come from [changes];
  /// none are looked for if [manual]. With [folders], the folder list
  /// loads only once it completes, and the start does not wait for it.
  Future<void> start({
    bool active = true,
    bool manual = false,
    Completer<void>? folders,
  }) async {
    // Broadcast: a rebuild listens again.
    changes = StreamController<ChangeHint>.broadcast();
    owner = _RecordingOwner();
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
        folderStateOwnerProvider.overrideWithValue(owner),
        refreshSettingsProvider.overrideWith(_FixedSettings.new),
      ],
    );
    addTearDown(container.dispose);
    container.listen(followingChangesProvider, (_, _) {});
    if (folders == null) await container.read(followingChangesProvider.future);
  }

  Future<void> settle() => pumpEventQueue();

  test('passes every hint on, with its base folder', () async {
    await start();

    changes
      ..add(PathChanged(path('a.md')))
      ..add(const ListAgain());
    await settle();

    expect(
      [
        for (final input in owner.inputs)
          if (input case Hinted(:final baseId, :final hint)) (baseId, hint),
      ],
      [
        (folder.base.id, PathChanged(path('a.md'))),
        (folder.base.id, const ListAgain()),
      ],
    );
  });

  test('tells the owner whether the app is in use', () async {
    await start();
    (container.read(appActiveProvider.notifier) as _FixedActivity).set(
      active: false,
    );
    await container.read(followingChangesProvider.future);

    expect(
      [
        for (final input in owner.inputs)
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
    await container.read(followingChangesProvider.future);

    expect(changes.hasListener, isFalse);
  });

  test('a start the app left meanwhile looks for no changes', () async {
    final folders = Completer<void>();
    await start(folders: folders);

    (container.read(appActiveProvider.notifier) as _FixedActivity).set(
      active: false,
    );
    await container.read(followingChangesProvider.future);
    folders.complete();
    await settle();

    expect(changes.hasListener, isFalse);
  });

  test('leaves catching up after a pause to the screens', () async {
    await start();
    final activity =
        container.read(appActiveProvider.notifier) as _FixedActivity
          ..set(active: false);
    await container.read(followingChangesProvider.future);

    activity.set(active: true);
    await container.read(followingChangesProvider.future);
    await settle();

    expect(owner.inputs.whereType<Hinted>(), isEmpty);
    expect(owner.inputs.whereType<Refresh>(), isEmpty);
    expect(changes.hasListener, isTrue);
  });

  test('lists again once when the refresh setting changes', () async {
    await start();

    (container.read(refreshSettingsProvider.notifier) as _FixedSettings).show(
      RefreshSettings.standard.copyWith(mode: RefreshMode.periodic),
    );
    await container.read(followingChangesProvider.future);

    await settle();

    expect(owner.inputs.whereType<Refresh>(), hasLength(1));
  });
}

final class _StreamChanges implements FolderChanges {
  _StreamChanges(this._controller);

  final StreamController<ChangeHint> _controller;

  @override
  Stream<ChangeHint> get changes => _controller.stream;
}

class _FixedFolders extends FoldersController {
  _FixedFolders(this._folders, {this._loaded});

  final List<DocumentFolder> _folders;
  final Future<void>? _loaded;

  @override
  FolderListState build() {
    if (_loaded == null) return FoldersLoaded(_folders);
    _loaded.then((_) => state = FoldersLoaded(_folders));
    return const FoldersLoading();
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

/// A folder state owner that records what it is told.
final class _RecordingOwner implements FolderStateOwner {
  final inputs = <FolderStateInput>[];

  @override
  void send(FolderStateInput input) => inputs.add(input);

  @override
  FolderState get state => FolderState.none;

  // Open while the app runs, as the real owner's.
  @override
  Stream<FolderState> get changes => StreamController<FolderState>().stream;

  @override
  Stream<Fresh> get events => StreamController<Fresh>().stream;

  @override
  Future<void> close() async {}
}
