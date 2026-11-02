import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/files/previews/card_preview_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_files/truce_files.dart';

import '../../support.dart';

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = tempFolder();
    container = ProviderContainer(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        deviceIdProvider.overrideWithValue('0123456789abcdef'),
      ],
    );
    addTearDown(container.dispose);
    await saveFolders(container, [folderAt(dir)]);
  });

  Future<ListedFile> listed(String name) async =>
      (await container.read(folderContentsProvider.future)).files
          .singleWhere((file) => file.path.value == name);

  test('a card shows the title and preview of the text read', () async {
    File('${dir.path}/plan.md').writeAsStringSync('# Plan\nsteps');
    final file = await listed('plan.md');
    final shown = container.listen(cardPreviewProvider(file), (_, _) {});
    expect(shown.read(), isA<PreviewReading>());

    await eventually(() => shown.read() is Previewed);

    final summary = (shown.read() as Previewed).summary;
    expect(summary.title, 'Plan');
    expect(summary.preview(ViewSettings.none), 'steps');
  });

  test(
    "a card says when a file can't be shown as text, and keeps it",
    () async {
      File('${dir.path}/plan.md').writeAsBytesSync([0xFF, 0xFE]);
      final file = await listed('plan.md');
      final previews = container.read(cardPreviewsProvider);

      expect(await previews.read(file), isA<PreviewNotText>());
      expect(previews.known(file), isA<PreviewNotText>());
    },
  );

  test('a card shown again shows its preview at once', () async {
    File('${dir.path}/plan.md').writeAsStringSync('# Plan');
    final file = await listed('plan.md');
    await container.read(cardPreviewsProvider).read(file);

    expect(container.read(cardPreviewProvider(file)), isA<Previewed>());
  });

  test('a card shown reads again once its preview passes', () async {
    var reads = 0;
    final previews = ProviderContainer(
      overrides: [
        cardPreviewsProvider.overrideWithValue(
          CardPreviews((_) async {
            reads++;
            return Previewed(
              FileCardSummary(
                title: 'Read $reads',
                preview: (_) => '',
                holdsUntil: DateTime.now().add(
                  const Duration(milliseconds: 100),
                ),
              ),
            );
          }),
        ),
      ],
    );
    addTearDown(previews.dispose);
    final file = listedFile(folderAt(dir), name: 'home.ics');
    final shown = previews.listen(cardPreviewProvider(file), (_, _) {});

    await eventually(
      () => switch (shown.read()) {
        Previewed(:final summary) => summary.title == 'Read 2',
        _ => false,
      },
    );
  });

  test('a card of a new version shows the version read before until the '
      'new one is read', () async {
    final file = File('${dir.path}/plan.md')..writeAsStringSync('# Plan');
    final before = await listed('plan.md');
    await container.read(cardPreviewsProvider).read(before);
    file.writeAsStringSync('# Plan, longer now');
    final after = ListedFile(
      folder: before.folder,
      path: before.path,
      type: before.type,
      version: FileVersion(-1),
      modified: before.modified,
    );

    final shown = container.listen(cardPreviewProvider(after), (_, _) {});
    expect((shown.read() as Previewed).summary.title, 'Plan');

    await eventually(
      () => (shown.read() as Previewed).summary.title == 'Plan, longer now',
    );
  });
}
