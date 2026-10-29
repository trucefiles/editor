import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/document_file.dart';
import 'package:truce_editor/document_page/document_pages.dart';
import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_editor/document_page/open_documents.dart';
import 'package:truce_editor/documents/delete_failure.dart';
import 'package:truce_editor/documents/document_settings.dart';

import '../support.dart';
import 'document_fixture.dart';

void main() {
  late DocumentFixture fixture;
  late OpenDocuments open;

  setUp(() async {
    fixture = await DocumentFixture.create();
    open = OpenDocuments();
  });

  DocumentPages pages() => DocumentPages(
    types: appDocumentTypes(),
    create: fixture.createFile,
    delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
    settingsOf: (_) => DocumentSettings.defaults,
    editSettings: (_, _) async {},
    filesOf: (folder) => fixture.files[folder.id]!,
    draftsOf: (folder) => fixture.drafts[folder.id]!,
    reachOf: (_) => Reach.reachable,
    reachSettled: (_) async => Reach.reachable,
    openDocuments: open,
    refreshFolders: () async {},
  );

  test('an open page is one of the open documents, and closes once its '
      'edits are in the file', () async {
    final page = pages().open(fixture.document, withFile: (_) async {});
    page.session.replaceAll('mine\n');

    // A folder change keeps the edits of the open documents first.
    await open.secureIn(fixture.folders[0].base);
    expect(fixture.onDisk('a.md'), 'mine\n');

    page.session.replaceAll('more\n');
    await page.close();

    expect(fixture.onDisk('a.md'), 'more\n');
    expect(page.session.state, isA<Ended>());
  });

  test("a new document's page goes where it is placed, of the type for new "
      'documents', () {
    final page = pages().openNew((
      folder: fixture.folders[1],
      subfolder: null,
    ), withFile: (_) async {});
    addTearDown(page.close);

    final file = page.session.file as NewFile;
    expect(file.folder.id, 'f2');
    expect(file.type, appDocumentTypes().forNew);
    expect(page.type, appDocumentTypes().forNew);
  });
}
