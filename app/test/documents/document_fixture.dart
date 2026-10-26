import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/conflicts/folder_conflicts.dart';
import 'package:truce_editor/documents/document_file.dart';
import 'package:truce_editor/documents/document_session.dart';
import 'package:truce_editor/documents/file_effects.dart';
import 'package:truce_editor/folders/note_folder.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_draft.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/scan/folder_scans.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../support.dart';

/// Two folders on disk, `f1` holding the note `a.md`, with their files,
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
          folder.id: NoteFiles(folder, servicesFor(folder)),
      },
      {for (final folder in folders) folder.id: tempDrafts()},
    );
    fixture.note = (await fixture.files['f1']!.create(
      'a',
      text: 'one\n',
    )).value;
    return fixture;
  }

  final List<Directory> dirs;
  final List<NoteFolder> folders;
  final Map<String, NoteFiles> files;
  final Map<String, NoteDrafts> drafts;
  late final Note note;

  /// A time after every draft written during the test.
  final later = DateTime.now().add(const Duration(days: 1));

  FileEffects effects(DocumentFile file) => FileEffects(
    file,
    filesOf: (folder) => files[folder.id]!,
    draftsOf: (folder) => drafts[folder.id]!,
    create: (place, {required title, required text}) => files[place.folder.id]!
        .create(title, subfolder: place.subfolder, text: text),
  );

  /// A session on [file], by default on [note]; disposed after the test.
  DocumentSession session([DocumentFile? file]) {
    final session = DocumentSession(effects(file ?? ExistingFile(note)));
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
  Future<List<NoteDraft>> draftsIn(String id) => drafts[id]!.all(before: later);

  /// The note as another device or app changed it to [text].
  Future<Note> editElsewhere(String text) async {
    File('${dirs[0].path}/a.md').writeAsStringSync(text);
    return (await files['f1']!.reload(note)).value;
  }

  /// A scan that starts now and finds [notes]; it could not read the
  /// files of [unread].
  FolderScans scanFinding(List<Note> notes, {Set<NoteKey> unread = const {}}) =>
      FolderScans(
        notes: notes,
        marks: const {},
        subfolders: const {},
        conflicts: FolderConflicts(const []),
        failedFolders: const {},
        unreadable: const {},
        startedAt: Moment.now(),
        unreadNotes: unread,
      );
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
