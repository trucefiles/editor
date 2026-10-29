import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../file_types/document_type.dart';
import '../folder_state/folder_contents.dart';
import '../folder_state/folder_state_controller.dart';
import '../folders/base_folder.dart';
import '../folders/document_folder.dart';
import '../folders/folder_selection.dart';
import '../reach/folder_reach_controller.dart';
import '../settings/device_settings_controller.dart';
import '../sync_tool/base_folder_wiring.dart';
import 'delete_failure.dart';
import 'deleted_document.dart';
import 'document.dart';
import 'document_place.dart';
import 'document_text.dart';
import 'documents_owner.dart';
import 'documents_wiring.dart';
import 'move_failure.dart';
import 'new_file_place/new_file_place.dart';

final documentActionsProvider = Provider<DocumentActions>(
  (ref) => DocumentActions(
    owner: ref.watch(documentsProvider).owner,
    selectedFolderId: () => ref.read(selectedFolderIdProvider),
    reachOf: (base) => ref.read(folderReachProvider(base)),
    newFilePlace: () =>
        ref.read(deviceSettingsProvider).requireValue.newFilePlace,
    contents: () => ref.read(folderContentsProvider).value,
    showsFolder: (base) => ref.read(showsFolderProvider(base)),
  ),
);

/// The user's actions on documents, and what screens need to offer them.
/// No UI: screens ask the user, then call these and show the result. Each
/// action runs in the documents [owner], after the ones asked before it.
final class DocumentActions {
  /// What the screens show now: [_selectedFolderId], the folder the grid is
  /// filtered to; [_reachOf], each base folder's reach; [_newFilePlace], the
  /// place set for new documents; [_contents], what the folders hold, as
  /// last seen (`null` before the first listing); [_showsFolder], whether a
  /// base folder's sync tool shows a folder.
  DocumentActions({
    required this._owner,
    required this._selectedFolderId,
    required this._reachOf,
    required this._newFilePlace,
    required this._contents,
    required this._showsFolder,
  });

  final DocumentsOwner _owner;
  final String? Function() _selectedFolderId;
  final Reach Function(BaseFolder base) _reachOf;
  final NewFilePlaceSetting? Function() _newFilePlace;
  final FolderContents? Function() _contents;
  final bool Function(RelPath folder) Function(BaseFolder base) _showsFolder;

  /// Where a new document goes without a place set for new documents:
  /// the one of [folders] the grid is filtered to, else the first.
  /// [folders] must not be empty.
  DocumentFolder defaultFolder(List<DocumentFolder> folders) {
    final selected = _selectedFolderId();
    return folders.where((folder) => folder.id == selected).firstOrNull ??
        folders.first;
  }

  /// Those of [folders] that new documents can go into: the ones that can be
  /// reached.
  List<DocumentFolder> reachableOf(List<DocumentFolder> folders) => [
    for (final folder in folders)
      if (_reachOf(folder.base) != Reach.unreachable) folder,
  ];

  /// Where a new document goes: the place the user set for new documents,
  /// if its folder is one of [folders], else the [defaultFolder] of
  /// [folders].
  DocumentPlace newFilePlace(List<DocumentFolder> folders) =>
      resolveNewFilePlace(_newFilePlace(), folders) ??
      topOf(defaultFolder(folders));

  /// The subfolders of [folder], as last seen.
  List<RelPath> subfoldersOf(DocumentFolder folder) =>
      _contents()?.subfoldersOf(folder.id) ?? const [];

  /// Whether documents of [folder] can go into [subfolder], an existing
  /// one or a new one: inside what the folder shows, in folders its sync
  /// tool shows (e.g. none of its own, no hidden one).
  bool canHold(DocumentFolder folder, RelPath subfolder) =>
      folder.selection.covers(subfolder) &&
      _showsFolder(folder.base)(subfolder);

  /// [document]'s color, as last seen.
  DocumentMark markOf(Document document) =>
      _contents()?.markOf(document.key) ?? DocumentMark.none;

  /// See [DocumentSteps.create].
  Future<Result<DocumentText, StoreError>> create(
    DocumentPlace place, {
    required DocumentType type,
    required String title,
    required String text,
    bool newSubfolder = false,
  }) async => switch (await _ask<DocumentCreated>(
    (ticket) => CreateDocument(
      ticket,
      place,
      type: type,
      title: title,
      text: text,
      newSubfolder: newSubfolder,
    ),
  )) {
    final answer? => answer.result,
    null => const Err(_notRun),
  };

  /// See [DocumentSteps.move].
  Future<Result<DocumentText, MoveFailure>> move(
    DocumentText document,
    DocumentPlace place, {
    String? title,
    bool newSubfolder = false,
  }) async => switch (await _ask<DocumentMoved>(
    (ticket) => MoveDocument(
      ticket,
      document,
      place,
      title: title,
      newSubfolder: newSubfolder,
    ),
  )) {
    final answer? => answer.result,
    null => const Err(MoveNotWritten(_notRun)),
  };

  /// See [DocumentSteps.delete].
  Future<Result<DeletedDocument, DeleteFailure>> delete(
    DocumentText document,
    String text,
  ) async => switch (await _ask<DocumentDeleted>(
    (ticket) => DeleteDocument(ticket, document, text),
  )) {
    final answer? => answer.result,
    null => const Err(DeleteNotDone(_notRun)),
  };

  /// See [DocumentSteps.undoDelete].
  Future<Result<void, StoreError>> undoDelete(DeletedDocument deleted) async =>
      switch (await _ask<DeleteUndone>(
        (ticket) => UndoDelete(ticket, deleted),
      )) {
        final answer? => answer.result,
        null => const Err(_notRun),
      };

  /// See [DocumentSteps.setMark].
  Future<Result<void, StoreError>> setMark(
    Document document,
    DocumentMark mark,
  ) async => switch (await _ask<MarkSet>(
    (ticket) => SetMark(ticket, document, mark),
  )) {
    final answer? => answer.result,
    null => const Err(_notRun),
  };

  /// The documents owner's answer to [asking]; `null` once the owner
  /// ended (a bug in an earlier action, or the app ends).
  Future<A?> _ask<A extends DocumentsAnswer>(
    DocumentsInput Function(Ticket ticket) asking,
  ) => ask<DocumentsInput, A>(_owner.send, _owner.events, asking);
}

/// How an action fails that never ran, as its owner had ended (a bug in
/// an earlier action, or the app ends): to the user, nothing was written,
/// so it reads as a failed write.
const _notRun = StoreError.ioFailure;
