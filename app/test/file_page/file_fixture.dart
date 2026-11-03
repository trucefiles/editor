import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart'
    show Err, FolderId, Ok, Result, StoreError, TextMerge;
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_markdown/truce_markdown.dart';

import '../support.dart';
import 'markdown_session.dart';

/// Two folders on disk, `f1` holding the file `a.md`, with their files,
/// drafts and backups. Everything is removed after the test.
final class FileFixture {
  FileFixture._(this.dirs, this.folders, this._services, this.drafts)
    : files = {
        for (final folder in folders)
          folder.id: FilesOfFolder(
            folder,
            _services[folder.id]!,
            appFileTypes(),
          ),
      };

  static Future<FileFixture> create() async {
    final dirs = [tempFolder(), tempFolder()];
    final folders = [folderAt(dirs[0]), folderAt(dirs[1], id: 'f2')];
    final fixture = FileFixture._(
      dirs,
      folders,
      {for (final folder in folders) folder.id: servicesFor(folder)},
      {for (final folder in folders) folder.id: tempDrafts()},
    );
    fixture.file = (await fixture.files[folderId('f1')]!.create(
      'a',
      type: appFileTypes().forNew,
      text: 'one\n',
    )).value;
    return fixture;
  }

  final List<Directory> dirs;
  final List<Folder> folders;
  final Map<FolderId, FolderServices> _services;
  final Map<FolderId, FilesOfFolder> files;
  final Map<FolderId, FileDrafts> drafts;
  late final FileText file;

  /// Closes folder `f1`, as when the user removes it: from then on its
  /// files refuse every read and write.
  Future<void> removeFirstFolder() => _services[folderId('f1')]!.open.close();

  /// A time after every draft written during the test.
  final later = DateTime.now().add(const Duration(days: 1));

  /// The effects of a session that starts at [file].
  FileEffects effects(PageFile file) => FileEffects(
    newFile: switch (file) {
      NewFile() => file,
      ExistingFile() => null,
    },
    filesOf: (folder) => files[folder.id]!,
    draftsOf: (folder) => drafts[folder.id]!,
    create: createFile,
    mover: moveFile,
  );

  /// Creates a file in the fixture's folders.
  Future<Result<FileText, StoreError>> createFile(
    FilePlace place, {
    required ShownFileType type,
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

  /// Moves a file in the fixture's folders: a copy at [place],
  /// then the old file removed.
  Future<Result<FileText, MoveFailure>> moveFile(
    FileText file,
    FilePlace place, {
    required String title,
    required bool newSubfolder,
  }) async {
    final copied = await files[place.folder.id]!.copyIn(
      file,
      file.text,
      subfolder: place.subfolder,
      newSubfolder: newSubfolder,
      title: title,
    );
    if (copied case Err(:final error)) return Err(MoveNotWritten(error));
    final copy = copied.value;
    return switch (await files[file.folder.id]!.delete(file.listed)) {
      Ok() => Ok(copy),
      Err(:final error) => Err(MoveLeftOriginal(copy, error)),
    };
  }

  /// A session on [file], by default on [this.file]; disposed after the test.
  FileSession session([PageFile? file, TextMerge? merge]) {
    final start = file ?? ExistingFile(this.file);
    final session = markdownSession(
      switch (start) {
        ExistingFile(file: final file) => file,
        NewFile() => null,
      },
      effects(start),
      merge: merge,
    );
    addTearDown(session.dispose);
    return session;
  }

  /// A new file going to the top of folder `f1`.
  NewFile get newFile => NewFile((
    folder: folders[0],
    subfolder: null,
  ), type: appFileTypes().forNew);

  /// The text of the file at [name] in folder [index]; `null` if none.
  String? onDisk(String name, {int index = 0}) {
    final file = File('${dirs[index].path}/$name');
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// The drafts kept in folder [id].
  Future<List<FileDraft>> draftsIn(String id) =>
      drafts[folderId(id)]!.all(before: later);

  /// The file as another device or app changed it to [text].
  Future<FileText> editElsewhere(String text) async {
    File('${dirs[0].path}/a.md').writeAsStringSync(text);
    return (await files[folderId('f1')]!.reload(file.listed)).value;
  }
}

extension Typing on FileSession {
  /// Types [text] at the caret, as the keyboard does; with none yet, at
  /// the start, as after a tap there.
  void type(String text) => gate.send(
    (now) => switch (now.content as FormattedContent) {
      FormattedContent(:final TextSelection selection) => Typed(
        text,
        over: selection,
        revision: now.revision,
      ),
      FormattedContent(:final view) => Typed(
        text,
        over: TextSelection.caret(Place(view.rows.first.leaf.id, 0)),
        revision: now.revision,
      ),
    },
  );
}
