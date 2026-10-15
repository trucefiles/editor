import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder_error.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/platform/host_paths.dart';
import 'package:truce_editor/platform/platform_wiring.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

import '../support.dart';

void main() {
  late AppStorage storage;

  setUp(() => storage = AppStorage(tempFolder().path));

  ProviderContainer container({HostPaths hostPaths = const SameHostPaths()}) {
    final container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(storage),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
        hostPathsProvider.overrideWithValue(hostPaths),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('adds a folder named after its last segment', () async {
    final folders = container();

    await folders.read(foldersProvider.notifier).add('/sync/Notes');

    final added = (await folders.read(foldersProvider.future)).single;
    expect(added.path, '/sync/Notes');
    expect(added.name, 'Notes');
  });

  test('adds a path only once, with distinct colors', () async {
    final folders = container();
    final controller = folders.read(foldersProvider.notifier);

    await controller.add('/sync/a');
    await controller.add('/sync/b');
    await controller.add('/sync/a');

    final list = await folders.read(foldersProvider.future);
    expect(list.map((f) => f.path), ['/sync/a', '/sync/b']);
    expect(list[0].color, isNot(list[1].color));
  });

  test('refuses a folder inside or holding an added one', () async {
    final folders = container();
    final controller = folders.read(foldersProvider.notifier);
    await controller.add('/sync/Notes');

    expect(
      (await controller.add('/sync/Notes/work/2026')).error,
      AddFolderError.overlaps,
    );
    expect((await controller.add('/sync')).error, AddFolderError.overlaps);
    expect(
      await controller.add('/sync/Notes/'),
      isA<Ok<void, AddFolderError>>(),
    );
    expect(
      await controller.add('/sync/Notes2'),
      isA<Ok<void, AddFolderError>>(),
    );

    final list = await folders.read(foldersProvider.future);
    expect(list.map((f) => f.path), ['/sync/Notes', '/sync/Notes2']);
  });

  test("refuses the sync tool's own folders, also on the host", () async {
    final folders = container(
      hostPaths: const _FakeHostPaths({
        '/doc/1/Notes': '/sync/.stversions/Notes',
      }),
    );
    final controller = folders.read(foldersProvider.notifier);

    expect(
      (await controller.add('/sync/.stversions')).error,
      AddFolderError.syncToolInternal,
    );
    expect(
      (await controller.add('/doc/1/Notes')).error,
      AddFolderError.syncToolInternal,
    );
    expect(await folders.read(foldersProvider.future), isEmpty);
  });

  test('refuses a folder that overlaps an added one on the host', () async {
    final folders = container(
      hostPaths: const _FakeHostPaths({
        '/doc/1/Notes': '/sync/Notes',
        '/doc/2/work': '/sync/Notes/work',
        '/doc/3/Notes': '/sync/Notes',
      }),
    );
    final controller = folders.read(foldersProvider.notifier);
    await controller.add('/doc/1/Notes');

    expect(
      (await controller.add('/doc/2/work')).error,
      AddFolderError.overlaps,
    );
    expect(
      await controller.add('/doc/3/Notes'),
      isA<Ok<void, AddFolderError>>(),
    );

    final added = (await folders.read(foldersProvider.future)).single;
    expect(added.path, '/doc/1/Notes');
    expect(added.name, 'Notes');
  });

  test('saves changes and removals for the next start', () async {
    final first = container();
    final controller = first.read(foldersProvider.notifier);
    await controller.add('/sync/a');
    await controller.add('/sync/b');
    final [a, b] = await first.read(foldersProvider.future);

    await controller.change(a.copyWith(name: 'Work'));
    await controller.remove(b);

    final loaded = await container().read(foldersProvider.future);
    expect(loaded.map((f) => (f.id, f.name)), [(a.id, 'Work')]);
  });
}

/// Host paths from a table; other paths are their own.
final class _FakeHostPaths implements HostPaths {
  const _FakeHostPaths(this._hostPaths);

  final Map<String, String> _hostPaths;

  @override
  Future<String> of(String path) async => _hostPaths[path] ?? path;
}
