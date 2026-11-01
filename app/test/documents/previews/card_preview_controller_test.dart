import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart' show FileVersion;
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_editor/documents/previews/card_preview_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

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
    await container.read(folderListStoreProvider).save([folderAt(dir)]);
  });

  Future<Document> listed(String name) async =>
      (await container.read(folderContentsProvider.future)).documents
          .singleWhere((document) => document.path.value == name);

  test('a card shows the title and preview of the text read', () async {
    File('${dir.path}/plan.md').writeAsStringSync('# Plan\nsteps');
    final document = await listed('plan.md');
    final shown = container.listen(cardPreviewProvider(document), (_, _) {});
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
      final document = await listed('plan.md');
      final previews = container.read(cardPreviewsProvider);

      expect(await previews.read(document), isA<PreviewNotText>());
      expect(previews.known(document), isA<PreviewNotText>());
    },
  );

  test('a card shown again shows its preview at once', () async {
    File('${dir.path}/plan.md').writeAsStringSync('# Plan');
    final document = await listed('plan.md');
    await container.read(cardPreviewsProvider).read(document);

    expect(container.read(cardPreviewProvider(document)), isA<Previewed>());
  });

  test('a card of a new version shows the version read before until the '
      'new one is read', () async {
    final file = File('${dir.path}/plan.md')..writeAsStringSync('# Plan');
    final before = await listed('plan.md');
    await container.read(cardPreviewsProvider).read(before);
    file.writeAsStringSync('# Plan, longer now');
    final after = Document(
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
