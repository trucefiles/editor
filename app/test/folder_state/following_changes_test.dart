import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folder_state/folder_state_wiring.dart';
import 'package:truce_editor/folder_state/following_changes.dart';
import 'package:truce_editor/refresh/refresh_settings.dart';
import 'package:truce_editor/settings/device_settings.dart';
import 'package:truce_editor/settings/device_settings_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';

void main() {
  late StreamController<ChangeHint> changes;
  late _RecordingOwner owner;
  late FollowingChanges following;

  setUp(() {
    changes = StreamController<ChangeHint>.broadcast();
    owner = _RecordingOwner();
    following = FollowingChanges(owner);
    addTearDown(following.close);
  });

  Map<String, FolderChanges> base1() => {'b1': _StreamChanges(changes)};

  Future<void> settle() => pumpEventQueue();

  test('passes every hint on, with its base folder', () async {
    following.follow(active: true, changes: base1());

    changes
      ..add(PathChanged(path('a.md')))
      ..add(const ListAgain());
    await settle();

    expect(
      [
        for (final input in owner.inputs)
          if (input case Hinted(:final baseId, :final hint)) (baseId, hint),
      ],
      [('b1', PathChanged(path('a.md'))), ('b1', const ListAgain())],
    );
  });

  test('tells the owner whether the app is in use', () {
    following
      ..follow(active: true, changes: base1())
      ..follow(active: true, changes: base1())
      ..follow(active: false, changes: base1());

    expect(
      [
        for (final input in owner.inputs)
          if (input case Active(:final active)) active,
      ],
      [true, false],
    );
  });

  test('does not look for changes while the app is not in use', () {
    following.follow(active: false, changes: base1());

    expect(changes.hasListener, isFalse);
  });

  test('does not look for changes when none are looked for', () {
    following.follow(active: true, changes: const {});

    expect(changes.hasListener, isFalse);
  });

  test('stops looking once the app is no longer in use', () async {
    following.follow(active: true, changes: base1());
    expect(changes.hasListener, isTrue);

    following.follow(active: false, changes: base1());
    await settle();

    expect(changes.hasListener, isFalse);
  });

  test('looks for the changes it is given once more, only', () async {
    final first = _StreamChanges(changes);
    following
      ..follow(active: true, changes: {'b1': first})
      ..follow(active: true, changes: {'b1': first});
    changes.add(PathChanged(path('a.md')));
    await settle();

    expect(owner.inputs.whereType<Hinted>(), hasLength(1));
  });

  test('leaves catching up after a pause to the screens', () async {
    following
      ..follow(active: true, changes: base1())
      ..follow(active: false, changes: base1())
      ..follow(active: true, changes: base1());
    await settle();

    expect(owner.inputs.whereType<Hinted>(), isEmpty);
    expect(owner.inputs.whereType<Refresh>(), isEmpty);
    expect(changes.hasListener, isTrue);
  });

  test('stops looking once closed', () async {
    following
      ..follow(active: true, changes: base1())
      ..close();
    await settle();

    expect(changes.hasListener, isFalse);
  });

  test('lists again once when the refresh setting changes', () async {
    final container = ProviderContainer(
      overrides: [
        folderStateOwnerProvider.overrideWithValue(owner),
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        loadedDeviceSettingsProvider.overrideWithValue(DeviceSettings.standard),
      ],
    );
    addTearDown(container.dispose);
    container.listen(followingChangesProvider, (_, _) {});

    await container
        .read(deviceSettingsProvider.notifier)
        .change(
          (settings) => settings.copyWith(
            refresh: RefreshSettings.standard.copyWith(
              mode: RefreshMode.periodic,
            ),
          ),
        );
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
