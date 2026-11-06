import 'dart:async';

import 'package:truce_core/truce_core.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import 'file_controller.dart';

/// Runs an action on the open file, created first for a new
/// file; if there is none, the action doesn't run and the user is told
/// why.
typedef WithFile = Future<void> Function(
  FutureOr<void> Function(ListedFile file) action,
);

/// One open file's page model, built by [FilePages]: its [type],
/// the editor's [part] and [view], the [session] joining its owners, and
/// the [controller] the screen shows.
final class FilePage {
  FilePage._(
    this.type,
    this.part,
    this.view,
    this.session,
    this.controller,
    this._leaveOpenFiles,
    this._closed,
  );

  final EditableType type;
  final EditorPart part;
  final EditorView view;
  final FileSession session;
  final FileController controller;
  final void Function() _leaveOpenFiles;
  final void Function() _closed;

  /// Closes the page; its edits are kept first, as far as they can be.
  /// Tells [FilePages.fileClosed] once securing began, not after: its
  /// last save needs no wait, as every own write is checked on its own.
  Future<void> close() {
    part.dispose();
    controller.dispose();
    // Also after a leave that kept the edits: the screen may also go
    // without one (its route removed), and a second answer is quick. It
    // stays an open file until then, so a folder change waits for it.
    final secured = session.secure(SecureReason.close).whenComplete(() {
      _leaveOpenFiles();
      session.dispose();
    });
    _closed();
    return secured;
  }
}

/// Builds the page model of each open file from the app's parts: the
/// one place that puts a page together.
final class FilePages {
  /// [filesOf] and [draftsOf] give a folder's files and drafts.
  /// [create], [move] and [delete] create, move and delete a file's
  /// file;
  /// [settingsOf] gives a file's settings, [editSettings] changes
  /// them. [reachOf] tells a folder's reach now, [reachSettled] once
  /// a running check of it is over. [fileClosed] is told as each page
  /// closes, e.g. so what shows next can be listed again.
  FilePages({
    required this.types,
    required this.create,
    required this.move,
    required this.delete,
    required this.settingsOf,
    required this.editSettings,
    required this.filesOf,
    required this.draftsOf,
    required this.reachOf,
    required this.reachSettled,
    required this.openFiles,
    required this.fileClosed,
  });

  final ShownFileTypes<EditableType> types;
  final FileCreator create;
  final FileMover move;
  final DeleteForUndo delete;
  final FileSettings Function(FileKey file) settingsOf;
  final EditSettings editSettings;
  final FilesOfFolder Function(Folder folder) filesOf;
  final FileDrafts Function(Folder folder) draftsOf;
  final Reach Function(FolderId folder) reachOf;
  final Future<Reach> Function(FolderId folder) reachSettled;
  final OpenFiles openFiles;
  final void Function() fileClosed;

  /// The page of [file], as read just before; the editor runs actions
  /// on its file through [withFile].
  FilePage open(FileText file, {required WithFile withFile}) => _open(
    types.ofFile(file.type),
    ExistingFile(file),
    view: settingsOf(file.key).view,
    withFile: withFile,
  );

  /// The page of a new file [made], to go into [place].
  FilePage openNew(
    FilePlace place, {
    required NewFileChoice<EditableType> made,
    required WithFile withFile,
  }) => _open(
    made.type,
    NewFile(place, type: made.type, start: made.kind.start),
    view: FileSettings.defaults.view,
    withFile: withFile,
  );

  /// The page of a file of [type] whose [file] is where it starts,
  /// shown as [view] keeps.
  FilePage _open(
    EditableType type,
    PageFile file, {
    required ViewSettings view,
    required WithFile withFile,
  }) {
    final (opened, newFile) = switch (file) {
      ExistingFile(file: final file) => (file, null),
      NewFile() => (null, file),
    };
    // Made below, over the session; the editor tells view changes only
    // once the page is open, so after it is made.
    late final FileController controller;
    final editor = type.openEditor(
      (
        text: switch (file) {
          ExistingFile(:final file) => file.text,
          NewFile(:final start) => start,
        },
        version: opened?.seen.version,
        view: view,
        // Not yet kept as a conflict copy: only an unreachable folder
        // makes it read only.
        readOnly: reachOf(file.folder.id) == Reach.unreachable,
        isNew: opened == null,
      ),
      EditorPage(
        keepView: (change) => controller.keepSettings(
          (settings) => settings.withView(change(settings.view)),
        ),
        withFile: withFile,
      ),
    );
    final session = FileSession(
      file,
      FileEffects(
        newFile: newFile,
        filesOf: filesOf,
        draftsOf: draftsOf,
        create: create,
        mover: move,
      ),
      editor.part.editor,
      merge: type.merge,
    );
    FolderId folder() => session.file.folder.id;
    controller = FileController(
      session,
      reach: () => reachOf(folder()),
      reachSettled: () => reachSettled(folder()),
      backUp: (text) async => switch (session.read) {
        final file? => await filesOf(file.folder).backUpCurrent(file, text),
        null => const Err(StoreError.notFound),
      },
      delete: delete,
      settingsOf: settingsOf,
      editSettings: editSettings,
    );
    // Shows the file only to read while it can't be edited.
    controller.addListener(
      () => editor.part.showReadOnly(readOnly: controller.readOnly),
    );
    final leaveOpenFiles = openFiles.add(
      folder: folder,
      secure: session.secure,
      written: session.written,
    );
    return FilePage._(
      type,
      editor.part,
      editor.view,
      session,
      controller,
      leaveOpenFiles,
      fileClosed,
    );
  }
}
