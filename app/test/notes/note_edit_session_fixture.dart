import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/common/moment.dart';
import 'package:truce_editor/notes/note.dart';
import 'package:truce_editor/notes/note_drafts.dart';
import 'package:truce_editor/notes/note_edit_session.dart';
import 'package:truce_editor/notes/note_files.dart';
import 'package:truce_editor/sync_tool/folder_services.dart';
import 'package:truce_editor/sync_tool/syncthing/syncthing_wiring.dart';

import '../support.dart';

/// The note `a.md` in a fresh Syncthing folder, and a [session] on it that
/// saves right away. Everything is removed after the test.
final class EditSessionFixture {
  EditSessionFixture._(this.dir, this.backups, this.services, this.files);

  static Future<EditSessionFixture> create() async {
    final dir = tempFolder();
    final backups = tempFolder();
    final folder = folderAt(dir);
    final services = syncthingFolderServices(
      folder.path,
      backupsPath: backups.path,
      deviceId: '0123456789abcdef',
      platform: hostFacts(),
    );
    final fixture = EditSessionFixture._(
      dir,
      backups,
      services,
      NoteFiles(folder, services),
    );
    fixture.note = (await fixture.files.create('a')).value;
    fixture.session = fixture.open();
    return fixture;
  }

  final Directory dir;
  final Directory backups;
  final FolderServices services;
  final NoteFiles files;
  late final Note note;
  late final NoteEditSession session;

  /// A time after every draft written during the test.
  final later = DateTime.now().add(const Duration(days: 1));

  /// A session on [note], or this fixture's note; disposed after the test.
  NoteEditSession open({
    Note? note,
    NoteFiles? files,
    NoteDrafts? drafts,
    Duration saveDelay = Duration.zero,
    // The session's own default.
    Duration publishDelay = const Duration(minutes: 1),
    Moment? writtenAt,
  }) {
    final session = NoteEditSession(
      note ?? this.note,
      files ?? this.files,
      drafts ?? tempDrafts(),
      saveDelay: saveDelay,
      publishDelay: publishDelay,
      writtenAt: writtenAt,
    );
    addTearDown(session.dispose);
    return session;
  }

  File file() => File('${dir.path}/a.md');

  String onDisk() => file().readAsStringSync();

  /// The backed-up texts, as `kind: text`.
  List<String> backedUp() => [
    for (final f in backups.listSync(recursive: true).whereType<File>())
      '${f.path.substring(backups.path.length + 1).split(RegExp('[./]'))[1]}: '
          '${f.readAsStringSync()}',
  ]..sort();

  void clearBackups() =>
      backups.listSync().forEach((f) => f.deleteSync(recursive: true));

  /// Puts a file where the backups go, so no backup can be made.
  void blockBackups() {
    backups.deleteSync();
    File(backups.path).writeAsStringSync('in the way');
  }

  /// Undoes [blockBackups].
  void unblockBackups() {
    File(backups.path).deleteSync();
    backups.createSync();
  }

  /// The texts of the sync conflict copies in the folder.
  List<String> conflictCopies() => [
    for (final f in dir.listSync())
      if (f.path.contains('.sync-conflict-')) File(f.path).readAsStringSync(),
  ];

  /// A session whose backups go to [backups]; it saves only when asked.
  NoteEditSession sessionBackingUpTo(FileStore backups) => open(
    files: NoteFiles(
      note.folder,
      FolderServices(
        store: services.store,
        scanner: services.scanner,
        syncToolName: services.syncToolName,
        conflicts: services.conflicts,
        backups: FileBackups(backups),
        restore: services.restore,
        marks: services.marks,
        reach: services.reach,
      ),
    ),
    saveDelay: const Duration(hours: 1),
  );

  /// Simulates an edit from another device and returns the new version.
  Future<Note> editElsewhere(String text) async {
    file().writeAsStringSync(text);
    return (await files.reload(note)).value;
  }

  /// Simulates a file system reporting a new version for unchanged content.
  Future<Note> restamp() async {
    file().setLastModifiedSync(DateTime(2001));
    return (await files.reload(note)).value;
  }
}

/// A temp store whose first [create] waits until [release] completes.
HeldStore heldTempStore() =>
    HeldStore(LocalFileStore(tempFolder().path, (t) => t, createsRoot: true));

/// Holds the first [create] until [release] completes.
final class HeldStore implements FileStore {
  HeldStore(this._inner);

  final FileStore _inner;
  final reached = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Result<FileEntry, StoreError>> create(
    RelPath path,
    Uint8List bytes,
  ) async {
    if (!reached.isCompleted) reached.complete();
    await release.future;
    return _inner.create(path, bytes);
  }

  @override
  Future<Result<Listing, StoreError>> list({
    bool Function(RelPath folder)? enterFolder,
    bool Function(RelPath file)? includeFile,
  }) => _inner.list(enterFolder: enterFolder, includeFile: includeFile);

  @override
  Future<Result<FileContent, StoreError>> read(RelPath path) =>
      _inner.read(path);

  @override
  Future<Result<FileEntry, StoreError>> replace(
    RelPath path,
    Uint8List bytes, {
    required FileVersion ifUnchanged,
  }) => _inner.replace(path, bytes, ifUnchanged: ifUnchanged);

  @override
  Future<Result<void, StoreError>> delete(
    RelPath path, {
    required FileVersion ifUnchanged,
  }) => _inner.delete(path, ifUnchanged: ifUnchanged);
}
