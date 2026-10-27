import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../folders/document_folder.dart';
import '../folders/folder_selection.dart';
import '../reach/folder_reach_controller.dart';
import '../scan/folder_scans_controller.dart';
import 'delete_failure.dart';
import 'deleted_note.dart';
import 'document.dart';
import 'document_place.dart';
import 'document_steps.dart';
import 'documents_owner.dart';
import 'move_failure.dart';
import 'new_document_place/new_document_place.dart';
import 'new_document_place/new_document_place_controller.dart';

final documentActionsProvider = Provider<DocumentActions>(DocumentActions.new);

/// The user's actions on documents, and what screens need to offer them.
/// No UI: screens ask the user, then call these and show the result. Each
/// action runs in the documents owner, after the ones asked before it.
final class DocumentActions {
  DocumentActions(this._ref);

  final Ref _ref;

  /// Where a new document goes without a place set for new documents: the one of
  /// [folders] the grid is filtered to, else the first. [folders] must not
  /// be empty.
  DocumentFolder defaultFolder(List<DocumentFolder> folders) {
    final selected = _ref.read(selectedFolderIdProvider);
    return folders.where((folder) => folder.id == selected).firstOrNull ??
        folders.first;
  }

  /// Those of [folders] that new documents can go into: the ones that can be
  /// reached.
  List<DocumentFolder> reachableOf(List<DocumentFolder> folders) => [
    for (final folder in folders)
      if (_ref.read(folderReachProvider(folder.location)) != Reach.unreachable)
        folder,
  ];

  /// Where a new document goes: the place the user set for new documents, if its
  /// folder is one of [folders], else the [defaultFolder] of [folders].
  DocumentPlace newNotePlace(List<DocumentFolder> folders) =>
      resolveNewNotePlace(_ref.read(newNotePlaceProvider).value, folders) ??
      (folder: defaultFolder(folders), subfolder: null);

  /// The subfolders of [folder], as last scanned.
  List<RelPath> subfoldersOf(DocumentFolder folder) =>
      _ref.read(folderScansProvider).value?.subfoldersOf(folder.id) ?? const [];

  /// [document]'s color, as last scanned.
  DocumentMark markOf(Document document) =>
      _ref.read(documentStepsProvider).markOf(document);

  /// See [DocumentSteps.create].
  Future<Result<Document, StoreError>> create(
    DocumentPlace place, {
    required String title,
    required String text,
  }) async => (await _ask<DocumentCreated>(
    (ticket) => CreateDocument(ticket, place, title: title, text: text),
  )).result;

  /// See [DocumentSteps.move].
  Future<Result<Document, MoveFailure>> move(
    Document document,
    String text,
    DocumentPlace place, {
    String? title,
  }) async => (await _ask<DocumentMoved>(
    (ticket) => MoveDocument(ticket, document, text, place, title: title),
  )).result;

  /// See [DocumentSteps.delete].
  Future<Result<DeletedNote, DeleteFailure>> delete(
    Document document,
    String text,
  ) async => (await _ask<DocumentDeleted>(
    (ticket) => DeleteDocument(ticket, document, text),
  )).result;

  /// See [DocumentSteps.undoDelete].
  Future<Result<void, StoreError>> undoDelete(DeletedNote deleted) async =>
      (await _ask<DeleteUndone>((ticket) => UndoDelete(ticket, deleted)))
          .result;

  /// See [DocumentSteps.setMark].
  Future<Result<void, StoreError>> setMark(
    Document document,
    DocumentMark mark,
  ) async =>
      (await _ask<MarkSet>((ticket) => SetMark(ticket, document, mark))).result;

  /// The documents owner's answer to [asking]. The owner runs every
  /// action sent before it closes, so a missing answer is a bug.
  Future<A> _ask<A extends DocumentsAnswer>(
    DocumentsInput Function(Ticket ticket) asking,
  ) async {
    final owner = _ref.read(documentsProvider).owner;
    final answer = await ask<DocumentsInput, A>(
      owner.send,
      owner.events,
      asking,
    );
    return answer ?? (throw StateError('asked after the app ended'));
  }
}
