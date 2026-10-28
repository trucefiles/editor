import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/document_page/document_file.dart';
import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_editor/document_page/file_effects.dart';
import 'package:truce_editor/documents/document.dart';
import 'package:truce_editor/documents/document_draft.dart';
import 'package:truce_editor/documents/document_drafts.dart';
import 'package:truce_editor/documents/document_files.dart';
import 'package:truce_editor/folders/document_folder.dart';
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
          folder.id: DocumentFiles(folder, servicesFor(folder)),
      },
      {for (final folder in folders) folder.id: tempDrafts()},
    );
    fixture.document = (await fixture.files['f1']!.create(
      'a',
      text: 'one\n',
    )).value;
    return fixture;
  }

  final List<Directory> dirs;
  final List<DocumentFolder> folders;
  final Map<String, DocumentFiles> files;
  final Map<String, DocumentDrafts> drafts;
  late final Document document;

  /// A time after every draft written during the test.
  final later = DateTime.now().add(const Duration(days: 1));

  FileEffects effects(DocumentFile file) => FileEffects(
    file,
    filesOf: (folder) => files[folder.id]!,
    draftsOf: (folder) => drafts[folder.id]!,
    create: (place, {required title, required text}) => files[place.folder.id]!
        .create(title, subfolder: place.subfolder, text: text),
  );

  /// A session on [file], by default on [document]; disposed after the test.
  DocumentSession session([DocumentFile? file]) {
    final session = markdownSession(effects(file ?? ExistingFile(document)));
    addTearDown(session.dispose);
    return session;
  }

  /// A new document going to the top of folder `f1`.
  NewFile get newFile => NewFile((folder: folders[0], subfolder: null));

  /// The text of the file at [name] in folder [index]; `null` if none.
  String? onDisk(String name, {int index = 0}) {
    final file = File('${dirs[index].path}/$name');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// The drafts kept in folder [id].
  Future<List<DocumentDraft>> draftsIn(String id) =>
      drafts[id]!.all(before: later);

  /// The document as another device or app changed it to [text].
  Future<Document> editElsewhere(String text) async {
    File('${dirs[0].path}/a.md').writeAsStringSync(text);
    return (await files['f1']!.reload(document)).value;
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
