import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart' show Err, Ok, Result, StoreError;
import 'package:truce_documents/truce_documents.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../support.dart';
import 'markdown_session.dart';

/// Two folders on disk, `f1` holding the document `a.md`, with their files,
/// drafts and backups. Everything is removed after the test.
final class DocumentFixture {
  DocumentFixture._(this.dirs, this.folders, this.files, this.drafts);

  static Future<DocumentFixture> create() async {
    final dirs = [tempFolder(), tempFolder()];
    final folders = [folderAt(dirs[0]), folderAt(dirs[1], id: 'f2')];
    final fixture = DocumentFixture._(
      dirs,
      folders,
      {
        for (final folder in folders)
          folder.id: DocumentFiles(
            folder,
            servicesFor(folder),
            appDocumentTypes(),
          ),
      },
      {for (final folder in folders) folder.id: tempDrafts()},
    );
    fixture.document = (await fixture.files['f1']!.create(
      'a',
      type: appDocumentTypes().forNew,
      text: 'one\n',
    )).value;
    return fixture;
  }

  final List<Directory> dirs;
  final List<DocumentFolder> folders;
  final Map<String, DocumentFiles> files;
  final Map<String, DocumentDrafts> drafts;
  late final DocumentText document;

  /// A time after every draft written during the test.
  final later = DateTime.now().add(const Duration(days: 1));

  /// The effects of a session that starts at [file], naming files from
  /// [summaries].
  FileEffects effects(DocumentFile file, [SentSummary? summaries]) =>
      FileEffects(
        newFile: switch (file) {
          NewFile() => file,
          ExistingFile() => null,
        },
        summaries: summaries ?? markdownSummaries(),
        filesOf: (folder) => files[folder.id]!,
        draftsOf: (folder) => drafts[folder.id]!,
        create: createFile,
        moveDocument: moveFile,
      );

  /// Creates a document's file in the fixture's folders.
  Future<Result<DocumentText, StoreError>> createFile(
    DocumentPlace place, {
    required DocumentType type,
    required String title,
    required String text,
    bool newSubfolder = false,
  }) => files[place.folder.id]!.create(
    title,
    type: type,
    subfolder: place.subfolder,
    newSubfolder: newSubfolder,
    text: text,
  );

  /// Moves a document's file in the fixture's folders: a copy at [place],
  /// then the old file removed.
  Future<Result<DocumentText, MoveFailure>> moveFile(
    DocumentText document,
    DocumentPlace place, {
    required String title,
    required bool newSubfolder,
  }) async {
    final copied = await files[place.folder.id]!.copyIn(
      document,
      document.text,
      subfolder: place.subfolder,
      newSubfolder: newSubfolder,
      title: title,
    );
    if (copied case Err(:final error)) return Err(MoveNotWritten(error));
    final copy = copied.value;
    return switch (await files[document.folder.id]!.delete(document.document)) {
      Ok() => Ok(copy),
      Err(:final error) => Err(MoveLeftOriginal(copy, error)),
    };
  }

  /// A session on [file], by default on [document]; disposed after the test.
  DocumentSession session([DocumentFile? file]) {
    final start = file ?? ExistingFile(document);
    final session = markdownSession(switch (start) {
      ExistingFile(:final document) => document,
      NewFile() => null,
    }, (summaries) => effects(start, summaries));
    addTearDown(session.dispose);
    return session;
  }

  /// A new document going to the top of folder `f1`.
  NewFile get newFile => NewFile((
    folder: folders[0],
    subfolder: null,
  ), type: appDocumentTypes().forNew);

  /// The text of the file at [name] in folder [index]; `null` if none.
  String? onDisk(String name, {int index = 0}) {
    final file = File('${dirs[index].path}/$name');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// The drafts kept in folder [id].
  Future<List<DocumentDraft>> draftsIn(String id) =>
      drafts[id]!.all(before: later);

  /// The document as another device or app changed it to [text].
  Future<DocumentText> editElsewhere(String text) async {
    File('${dirs[0].path}/a.md').writeAsStringSync(text);
    return (await files['f1']!.reload(document.document)).value;
  }
}

extension Typing on DocumentSession {
  /// Types [text] at the caret, as the keyboard does.
  void type(String text) => gate.send(
    (now) => Typed(
      text,
      over: (now.content as FormattedContent).selection as TextSelection,
      revision: now.revision,
    ),
  );
}
