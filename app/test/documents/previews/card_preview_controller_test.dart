import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_settings.dart';
import 'package:truce_editor/documents/previews/card_preview.dart';
import 'package:truce_editor/documents/previews/card_preview_controller.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';

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
    expect(summary.preview(DocumentSettings.defaults), 'steps');
  });

  test("a card says when a file can't be shown as text", () async {
    File('${dir.path}/plan.md').writeAsBytesSync([0xFF, 0xFE]);
    final document = await listed('plan.md');

    expect(
      await container.read(cardPreviewsProvider).read(document),
      isA<PreviewUnreadable>(),
    );
  });

  test('a card shown again shows its preview at once', () async {
    File('${dir.path}/plan.md').writeAsStringSync('# Plan');
    final document = await listed('plan.md');
    await container.read(cardPreviewsProvider).read(document);

    expect(container.read(cardPreviewProvider(document)), isA<Previewed>());
  });
}
