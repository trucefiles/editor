import 'dart:async';

import 'package:truce_core/truce_core.dart';

import '../documents/document.dart';
import '../documents/document_actions.dart';
import '../documents/document_drafts.dart';
import '../documents/document_files.dart';
import '../documents/document_place.dart';
import '../documents/document_settings.dart';
import '../documents/document_settings_controller.dart';
import '../documents/document_text.dart';
import '../documents/document_types.dart';
import '../documents/document_version.dart';
import '../documents/view_settings.dart';
import '../editor/editor_view.dart';
import '../file_types/editable_type.dart';
import '../folders/base_folder.dart';
import '../folders/document_folder.dart';
import 'document_controller.dart';
import 'document_file.dart';
import 'document_session.dart';
import 'editor_part.dart';
import 'file_effects.dart';
import 'open_documents.dart';

/// Runs an action on the open document's file, created first for a new
/// document; if there is none, the action doesn't run and the user is told
/// why.
typedef WithFile = Future<void> Function(
  FutureOr<void> Function(Document document) action,
);

/// One open document's page model, built by [DocumentPages]: its [type],
/// the editor's [part] and [view], the [session] joining its owners, and
/// the [controller] the screen shows.
final class DocumentPage {
  DocumentPage._(
    this.type,
    this.part,
    this.view,
    this.session,
    this.controller,
    this._leaveOpenDocuments,
  );

  final EditableType type;
  final EditorPart part;
  final EditorView view;
  final DocumentSession session;
  final DocumentController controller;
  final void Function() _leaveOpenDocuments;

  /// Closes the page; its edits are kept first, as far as they can be.
  Future<void> close() {
    part.dispose();
    controller.dispose();
    // Also after a leave that kept the edits: the screen may also go
    // without one (its route removed), and a second answer is quick. It
    // stays an open document until then, so a folder change waits for it.
    return session.secure(SecureReason.close).whenComplete(() {
      _leaveOpenDocuments();
      session.dispose();
    });
  }
}

/// Builds the page model of each open document from the app's parts: the
/// one place that puts a page together.
final class DocumentPages {
  /// [actions] and [settings] give the document actions and settings as
  /// they are as a page opens; [filesOf] and [draftsOf] a folder's
  /// document files and drafts as they are when asked. [reachOf] tells a
  /// base folder's reach now, [reachSettled] once a running check of it
  /// is over. [refreshFolders] lists the folders again.
  DocumentPages({
    required this.types,
    required this.actions,
    required this.settings,
    required this.filesOf,
    required this.draftsOf,
    required this.reachOf,
    required this.reachSettled,
    required this.openDocuments,
    required this.refreshFolders,
  });

  final DocumentTypes<EditableType> types;
  final DocumentActions Function() actions;
  final DocumentSettingsController Function() settings;
  final DocumentFiles Function(DocumentFolder folder) filesOf;
  final DocumentDrafts Function(DocumentFolder folder) draftsOf;
  final Reach Function(BaseFolder base) reachOf;
  final Future<Reach> Function(BaseFolder base) reachSettled;
  final OpenDocuments openDocuments;
  final Future<void> Function() refreshFolders;

  /// The page of [document], as read just before; the editor runs actions
  /// on its file through [withFile].
  DocumentPage open(DocumentText document, {required WithFile withFile}) =>
      _open(
        types.ofFile(document.type),
        ExistingFile(document),
        view: settings().settingsOf(document.key).view,
        withFile: withFile,
      );

  /// The page of a new document, to go into [place].
  DocumentPage openNew(DocumentPlace place, {required WithFile withFile}) {
    final type = types.forNew;
    return _open(
      type,
      NewFile(place, type: type),
      view: DocumentSettings.defaults.view,
      withFile: withFile,
    );
  }

  /// The page of a document of [type] whose [file] is where it starts,
  /// shown as [view] keeps.
  DocumentPage _open(
    EditableType type,
    DocumentFile file, {
    required ViewSettings view,
    required WithFile withFile,
  }) {
    final (opened, newFile) = switch (file) {
      ExistingFile(:final document) => (document, null),
      NewFile() => (null, file),
    };
    final actionsNow = actions();
    final settingsNow = settings();
    late final DocumentController controller;
    final editor = type.openEditor(
      (
        text: opened?.text ?? '',
        version: opened?.seen.version,
        view: view,
        // Not yet kept as a conflict copy: only an unreachable folder
        // makes it read only.
        readOnly: reachOf(file.folder.base) == Reach.unreachable,
        isNew: opened == null,
      ),
      EditorPage(
        keepView: (change) => controller.keepSettings(
          (settings) => settings.withView(change(settings.view)),
        ),
        withFile: withFile,
      ),
    );
    final session = DocumentSession(
      opened,
      FileEffects(
        newFile: newFile,
        filesOf: filesOf,
        draftsOf: draftsOf,
        create: actionsNow.create,
      ),
      editor.part.editor,
    );
    BaseFolder base() => session.file.folder.base;
    controller = DocumentController(
      session,
      reach: () => reachOf(base()),
      reachSettled: () => reachSettled(base()),
      backUp: (text) async => switch (session.document) {
        final document? => await filesOf(
          document.folder,
        ).backUpCurrent(document, text),
        null => const Err(StoreError.notFound),
      },
      delete: actionsNow.delete,
      settingsOf: settingsNow.settingsOf,
      editSettings: settingsNow.edit,
    );
    // Shows the document only to read while it can't be edited.
    controller.addListener(
      () => editor.part.showReadOnly(readOnly: controller.readOnly),
    );
    final leaveOpenDocuments = openDocuments.add(
      base: base,
      secure: () => session.secure(SecureReason.hide),
    );
    // Opening a document lists the folders again, as the refresh setting
    // promises; its own text was read just before.
    unawaited(refreshFolders());
    return DocumentPage._(
      type,
      editor.part,
      editor.view,
      session,
      controller,
      leaveOpenDocuments,
    );
  }
}
