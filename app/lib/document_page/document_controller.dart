import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import '../documents/delete_failure.dart';
import '../documents/deleted_document.dart';
import '../documents/document.dart';
import '../documents/document_settings.dart';
import '../documents/document_text.dart';
import '../folder_state/folder_contents.dart';
import '../folders/document_folder.dart';
import '../folders/folder_lookup.dart';
import 'document_file.dart';
import 'document_session.dart';

/// Backs up [text], the open document's text now.
typedef BackUpText = Future<Result<void, StoreError>> Function(String text);

/// Deletes a document holding a text, so it can be undone.
typedef DeleteDocument =
    Future<Result<DeletedDocument, DeleteFailure>> Function(
      DocumentText document,
      String text,
    );

/// Changes the settings of a document on this device.
typedef EditSettings = Future<void> Function(
  DocumentKey document,
  DocumentSettings Function(DocumentSettings settings) change,
);

/// How deleting the open document ended.
sealed class DeleteOutcome {
  const DeleteOutcome();
}

/// A new document, without a file yet: dropped.
final class NewDropped extends DeleteOutcome {
  const NewDropped();
}

/// The document was deleted; [deleted] can write it back.
final class DocumentDeleted extends DeleteOutcome {
  const DocumentDeleted(this.deleted);

  final DeletedDocument deleted;
}

/// The document's file is gone already: nothing was deleted.
final class AlreadyGone extends DeleteOutcome {
  const AlreadyGone();
}

/// The document stopped taking edits (a bug); it is not deleted.
final class DocumentStopped extends DeleteOutcome {
  const DocumentStopped();
}

/// The document is still there, for [failure].
final class DeleteRefused extends DeleteOutcome {
  const DeleteRefused(this.failure);

  final DeleteFailure failure;
}

/// Why the open document has no file to act on.
enum NoFile {
  /// A new document with no text yet: it is not saved.
  empty,

  /// Its file could not be created; the screen's banner tells why.
  notCreated,

  /// The document stopped taking edits (a bug); nothing acts on it.
  stopped,
}

/// Whether the folders still show the open document.
enum DocumentShown {
  /// A folder shows it.
  shown,

  /// Its folder no longer shows the place it is in.
  narrowedAway,

  /// Its folder was removed.
  folderRemoved,
}

/// How restoring a backup into the open document ended.
enum RestoreOutcome {
  /// The backup's text shows, as one edit undo takes back.
  restored,

  /// Nothing changed: the document can't be edited here (anymore).
  notEditable,

  /// Nothing changed: the text now could not be backed up first.
  notBackedUp,
}

/// The open document's view model: whether it can be edited or left now,
/// whether its edits are kept as the user leaves or quits, deleting it,
/// its file for the actions that need one, its mark and settings on this
/// device, whether a folder still shows it, and backups restored into it.
/// No UI. Listeners hear of every change of the [session], and of its
/// folder's reach.
final class DocumentController extends ChangeNotifier {
  /// [reach]: the reach of the document's folder now; [reachSettled]: once
  /// a running check of it is over. [backUp]: backs up the document's
  /// text. [delete] deletes it; [settingsOf] gives a document's settings,
  /// [editSettings] changes them.
  DocumentController(
    this.session, {
    required this.reach,
    required this.reachSettled,
    required this.backUp,
    required this.delete,
    required this.settingsOf,
    required this.editSettings,
  }) {
    _following = session.changes.listen((_) {
      _keepOnceFiled();
      notifyListeners();
    });
  }

  final DocumentSession session;
  final Reach Function() reach;
  final Future<Reach> Function() reachSettled;
  final BackUpText backUp;
  final DeleteDocument delete;
  final DocumentSettings Function(DocumentKey document) settingsOf;
  final EditSettings editSettings;
  late final StreamSubscription<void> _following;

  /// The reach of the document's folder changed.
  void reachChanged() => notifyListeners();

  /// Whether the document's folder can't be reached now.
  bool get unreachable => reach() == Reach.unreachable;

  /// Whether the document is only shown to read: its edits were kept as a
  /// conflict copy, its folder can't be reached, or it stopped (a bug).
  bool get readOnly =>
      session.status is KeptAsConflict ||
      unreachable ||
      session.state is! Running;

  /// Whether the user can leave at once: nothing is left to keep.
  bool get canLeaveNow => switch (session.status) {
    InStep() || Unwritten() => !session.editor.state.unsent,
    KeptAsConflict() || Closed() => true,
    Editing() ||
    ChangedElsewhere() ||
    DeletedElsewhere() ||
    SaveFailed() => false,
  };

  /// The document's settings on this device; the defaults until it has a
  /// file.
  DocumentSettings get settings => switch (session.document) {
    final document? => settingsOf(document.key),
    null => DocumentSettings.defaults,
  };

  /// The document's mark as [contents] know it; none until it has a file.
  DocumentMark markIn(FolderContents? contents) => switch (session.document) {
    final document? => contents?.markOf(document.key) ?? DocumentMark.none,
    null => DocumentMark.none,
  };

  /// Whether [folders] still show the document, where it is now.
  DocumentShown shownIn(List<DocumentFolder> folders) {
    final file = session.file;
    final folder = file.folder;
    if (folders.folderOf(folder.base.id, file.pathFor(session.text)) != null) {
      return DocumentShown.shown;
    }
    return folders.any((shown) => shown.id == folder.id)
        ? DocumentShown.narrowedAway
        : DocumentShown.folderRemoved;
  }

  /// Settings changes made before the document had a file, to keep once
  /// it has, in order.
  final _toKeep = <DocumentSettings Function(DocumentSettings)>[];

  /// Changes the document's settings on this device by [change]; for a
  /// new document, once it has a file.
  void keepSettings(DocumentSettings Function(DocumentSettings) change) {
    _toKeep.add(change);
    _keepOnceFiled();
  }

  void _keepOnceFiled() {
    final document = session.document;
    if (document == null || _toKeep.isEmpty) return;
    final changes = [..._toKeep];
    _toKeep.clear();
    unawaited(
      editSettings(
        document.key,
        (settings) =>
            changes.fold(settings, (settings, change) => change(settings)),
      ),
    );
  }

  /// Whether the user may go for [reason] (leave the document, quit the
  /// app): once the edits are kept ([keep]), or the user drops them when
  /// [askToDiscard]; then the session drops them.
  Future<bool> mayGo(
    SecureReason reason,
    Future<bool> Function() askToDiscard,
  ) async {
    if (await keep(reason)) return true;
    if (!await askToDiscard()) return false;
    session.discard();
    return true;
  }

  /// Keeps the edits for [reason] ([DocumentSession.secure]); whether
  /// they are kept: in the file or a conflict copy, or on this device
  /// while the folder can't be reached. A failed save may just have
  /// started a check of the folder, so this waits for its outcome. Once
  /// the session stopped, whether it kept them on this device.
  Future<bool> keep(SecureReason reason) async {
    // Kept on this device by the session itself, if it could.
    if (session.state case Stopped(:final kept)) return kept ?? false;
    if (await session.secure(reason)) return true;
    return await reachSettled() == Reach.unreachable;
  }

  /// Deletes the document with every edit sent; a new document is just
  /// dropped.
  Future<DeleteOutcome> deleteDocument() async {
    // Its edits wait on this device for the next start.
    if (session.state is! Running) return const DocumentStopped();
    if (session.file is NewFile) {
      session.discard();
      return const NewDropped();
    }
    await session.secure(SecureReason.hide);
    final document = session.document;
    if (document == null) return const AlreadyGone();
    return switch (await delete(document, session.text)) {
      Ok(:final value) => DocumentDeleted(value),
      Err(:final error) => DeleteRefused(error),
    };
  }

  /// The document's file, with every edit sent, for an action that needs
  /// one; a new document's file is created first.
  Future<Result<DocumentText, NoFile>> withFile() async {
    if (session.state is! Running) return const Err(NoFile.stopped);
    await session.secure(SecureReason.hide);
    return switch ((session.document, session.status)) {
      (final document?, _) => Ok(document),
      (null, Unwritten()) => const Err(NoFile.empty),
      (null, _) => const Err(NoFile.notCreated),
    };
  }

  /// Stops following the session.
  @override
  void dispose() {
    unawaited(_following.cancel());
    super.dispose();
  }

  /// The document's text with every edit sent, to compare a backup with.
  Future<String> textNow() async {
    await session.secure(SecureReason.hide);
    return session.text;
  }

  /// Puts [backup], a backup's text, in place of the document's text, as
  /// one edit undo takes back; first the text now, with every edit sent,
  /// is backed up.
  Future<RestoreOutcome> restore(String backup) async {
    final now = await textNow();
    if (readOnly) return RestoreOutcome.notEditable;
    if (await backUp(now) is Err) return RestoreOutcome.notBackedUp;
    session.replaceAll(backup);
    return RestoreOutcome.restored;
  }
}
