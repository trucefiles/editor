import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder_error.dart';
import 'package:truce_editor/folders/folder_actions.dart';
import 'package:truce_editor/folders/folder_selection.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';
import 'package:truce_editor/platform/folder_picker.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/storage_access.dart';

import '../support.dart';

void main() {
  late _FakePicker picker;
  late _FakeAccess access;
  late ProviderContainer container;
  late FolderActions actions;

  setUp(() {
    picker = _FakePicker();
    access = _FakeAccess();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        folderPickerProvider.overrideWithValue(picker),
        storageAccessProvider.overrideWithValue(access),
        hostPathsProvider.overrideWithValue(const SameHostPaths()),
      ],
    );
    addTearDown(container.dispose);
    actions = container.read(folderActionsProvider);
  });

  Future<List<String>> paths() async => [
    for (final folder in await container.read(foldersProvider.future))
      folder.path,
  ];

  test('asks the platform for access', () async {
    expect(await actions.hasAccess(), isFalse);

    await actions.requestAccess();

    expect(await actions.hasAccess(), isTrue);
  });

  test('adds the picked folder', () async {
    picker.result = const Ok('/sync/Notes');

    expect(await actions.pickAndAdd(), isA<Ok<void, AddFolderError>>());

    expect(await paths(), ['/sync/Notes']);
  });

  test('adds nothing if the user cancels', () async {
    picker.result = const Ok(null);

    expect(await actions.pickAndAdd(), isA<Ok<void, AddFolderError>>());

    expect(await paths(), isEmpty);
  });

  test('reports a folder the app cannot open', () async {
    picker.result = const Err(PickError.unsupportedLocation);

    final added = await actions.pickAndAdd();

    expect(added.error, AddFolderError.unsupportedLocation);
    expect(await paths(), isEmpty);
  });

  test('reports a folder inside an added one', () async {
    picker.result = const Ok('/sync/Notes');
    await actions.pickAndAdd();
    picker.result = const Ok('/sync/Notes/work');

    final added = await actions.pickAndAdd();

    expect(added.error, AddFolderError.overlaps);
    expect(await paths(), ['/sync/Notes']);
  });

  test('remove stops filtering the notes by that folder', () async {
    picker.result = const Ok('/sync/a');
    await actions.pickAndAdd();
    picker.result = const Ok('/sync/b');
    await actions.pickAndAdd();
    final [a, b] = await container.read(foldersProvider.future);
    final selection = container.read(selectedFolderIdProvider.notifier);

    selection.choose(b.id);
    await actions.remove(a);
    expect(container.read(selectedFolderIdProvider), b.id);

    await actions.remove(b);
    expect(container.read(selectedFolderIdProvider), isNull);
    expect(await paths(), isEmpty);
  });

  test('change saves the folder', () async {
    picker.result = const Ok('/sync/a');
    await actions.pickAndAdd();
    final [a] = await container.read(foldersProvider.future);

    await actions.change(a.copyWith(name: 'Work'));

    final [changed] = await container.read(foldersProvider.future);
    expect(changed.name, 'Work');
  });
}

final class _FakePicker implements FolderPicker {
  Result<String?, PickError> result = const Ok(null);

  @override
  Future<Result<String?, PickError>> pick() async => result;
}

final class _FakeAccess implements StorageAccess {
  bool _granted = false;

  @override
  Future<bool> isGranted() async => _granted;

  @override
  Future<void> request() async => _granted = true;
}
