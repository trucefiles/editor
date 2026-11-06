import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../app_end/app_end.dart';

/// Backs up [text], the open file's text now.
typedef BackUpText = Future<Result<void, StoreError>> Function(String text);

/// Deletes a file holding a text, so it can be undone.
typedef DeleteForUndo = Future<Result<UndoableDelete, DeleteFailure>> Function(
  FileText file,
  String text,
);

/// Changes the settings of a file on this device.
typedef EditSettings = Future<void> Function(
  FileKey file,
  FileSettings Function(FileSettings settings) change,
);

/// How deleting the open file ended.
sealed class DeleteOutcome {
  const DeleteOutcome();
}

/// A new file, without a file yet: dropped.
final class NewDropped extends DeleteOutcome {
  const NewDropped();
}

/// The file was deleted; [deleted] can write it back.
final class DeletedForUndo extends DeleteOutcome {
  const DeletedForUndo(this.deleted);

  final UndoableDelete deleted;
}

/// The file is gone already: nothing was deleted.
final class AlreadyGone extends DeleteOutcome {
  const AlreadyGone();
}

/// The file stopped taking edits (a bug); it is not deleted.
final class FileStopped extends DeleteOutcome {
  const FileStopped();
}

/// The file is still there, for [failure].
final class DeleteRefused extends DeleteOutcome {
  const DeleteRefused(this.failure);

  final DeleteFailure failure;
}

/// Why the open file has no file to act on.
enum NoFile {
  /// A new file with no text yet: it is not saved.
  empty,

  /// Its file could not be created; the screen's banner tells why.
  notCreated,

  /// The file stopped taking edits (a bug); nothing acts on it.
  stopped,
}

/// How restoring a backup into the open file ended.
enum RestoreOutcome {
  /// The backup's text shows, as one edit undo takes back.
  restored,

  /// Nothing changed: the file can't be edited here (anymore).
  notEditable,

  /// Nothing changed: the text now could not be backed up first.
  notBackedUp,
}

/// The open file's view model: whether it can be edited or left now,
/// whether its edits are kept as the user leaves or quits, deleting it,
/// its file for the actions that need one, its mark and settings on this
/// device, whether a folder still shows it, and backups restored into it.
/// No UI. Listeners hear of every change of the [session], and of its
/// folder's reach.
final class FileController extends ChangeNotifier {
  /// [reach]: the reach of the file's folder now; [reachSettled]: once
  /// a running check of it is over. [backUp]: backs up the file's
  /// text. [delete] deletes it; [settingsOf] gives a file's settings,
  /// [editSettings] changes them.
  FileController(
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

  final FileSession session;
  final Reach Function() reach;
  final Future<Reach> Function() reachSettled;
  final BackUpText backUp;
  final DeleteForUndo delete;
  final FileSettings Function(FileKey file) settingsOf;
  final EditSettings editSettings;
  late final StreamSubscription<void> _following;

  /// The reach of the file's folder changed.
  void reachChanged() => notifyListeners();

  /// Whether the file's folder can't be reached now.
  bool get unreachable => reach() == Reach.unreachable;

  /// Whether the file is only shown to read: its edits were kept as a
  /// conflict copy, it closed and takes no more edits (its folder is
  /// being removed), its folder can't be reached, or it stopped.
  bool get readOnly =>
      session.status is KeptAsConflict ||
      session.status is Closed ||
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

  /// The file's settings on this device; the defaults until it has a
  /// file.
  FileSettings get settings => switch (session.read) {
    final file? => settingsOf(file.key),
    null => FileSettings.defaults,
  };

  /// The file's mark as [shown] holds it; none until it has a file.
  FileMark markIn(FolderFiles? shown) => switch (session.read) {
    final file? => shown?.markOf(file.key) ?? FileMark.none,
    null => FileMark.none,
  };

  /// The file's folder left the app. `true` if the page may close, as
  /// nothing is unsaved; else the file stops taking edits and keeps
  /// showing them, so they can be copied before it closes. A file that
  /// stopped before stays as it is.
  bool folderRemoved() {
    if (session.state is! Running) return false;
    if (session.saveState case SaveState.inFolder || SaveState.none) {
      return true;
    }
    session.folderRemoved();
    return false;
  }

  /// Whether [folders] still hold the file's folder.
  bool folderShownIn(List<Folder> folders) =>
      folders.any((shown) => shown.id == session.file.folder.id);

  /// Settings changes made before the file had a file, to keep once
  /// it has, in order.
  final _toKeep = <FileSettings Function(FileSettings)>[];

  /// Changes the file's settings on this device by [change]; for a
  /// new file, once it has a file.
  void keepSettings(FileSettings Function(FileSettings) change) {
    _toKeep.add(change);
    _keepOnceFiled();
  }

  void _keepOnceFiled() {
    final file = session.read;
    if (file == null || _toKeep.isEmpty) return;
    final changes = [..._toKeep];
    _toKeep.clear();
    unawaited(
      editSettings(
        file.key,
        (settings) =>
            changes.fold(settings, (settings, change) => change(settings)),
      ),
    );
  }

  /// Whether the user may go for [reason] (leave the file, quit the
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

  /// Keeps the edits for [reason] ([FileSession.secure]); whether
  /// they are kept: in the file or a conflict copy, or on this device
  /// while the folder can't be reached; as the app ends, on this device
  /// is enough, and an answer later than [appEndWait] is none. A failed
  /// save may just have
  /// started a check of the folder, so this waits for its outcome. Once
  /// the session stopped, whether it kept them on this device.
  Future<bool> keep(SecureReason reason) async {
    // Kept on this device by the session itself, if it could.
    if (session.state case Stopped(:final kept)) return kept ?? false;
    final secured = session.secure(reason);
    // The app's end never waits on a folder that hangs: not kept then.
    if (await switch (reason) {
      SecureReason.exit => secured.timeout(appEndWait, onTimeout: () => false),
      SecureReason.close || SecureReason.hide => secured,
    }) {
      return true;
    }
    return await reachSettled() == Reach.unreachable;
  }

  /// Deletes the file with every edit sent; a new file is just
  /// dropped.
  Future<DeleteOutcome> deleteFile() async {
    // Its edits wait on this device for the next start.
    if (session.state is! Running) return const FileStopped();
    if (session.file is NewFile) {
      session.discard();
      return const NewDropped();
    }
    await session.secure(SecureReason.hide);
    final file = session.read;
    if (file == null) return const AlreadyGone();
    return switch (await delete(file, session.text)) {
      Ok(:final value) => DeletedForUndo(value),
      Err(:final error) => DeleteRefused(error),
    };
  }

  /// The file, with every edit sent, for an action that needs
  /// one; a new file is created first.
  Future<Result<FileText, NoFile>> withFile() async {
    if (session.state is! Running) return const Err(NoFile.stopped);
    await session.secure(SecureReason.hide);
    return switch ((session.read, session.status)) {
      (final file?, _) => Ok(file),
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

  /// The file's text with every edit sent, to compare a backup with.
  Future<String> textNow() async {
    await session.secure(SecureReason.hide);
    return session.text;
  }

  /// Puts [backup], a backup's text, in place of the file's text, as
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
