import 'package:truce_core/truce_core.dart';

import 'document_session.dart';

/// Backs up [text], the open document's text now.
typedef BackUpText = Future<Result<void, StoreError>> Function(String text);

/// How restoring a backup into the open document ended.
enum RestoreOutcome {
  /// The backup's text shows, as one edit undo takes back.
  restored,

  /// Nothing changed: the document can't be edited here (anymore).
  notEditable,

  /// Nothing changed: the text now could not be backed up first.
  notBackedUp,
}

/// The open document's view model: whether its edits are kept as the
/// user leaves, and backups restored into it. No UI.
final class DocumentController {
  /// [reachSettled]: the reach of the document's folder once a running
  /// check of it is over. [backUp]: backs up the document's text.
  /// [canEdit]: whether the document can be edited here now.
  DocumentController(
    this.session, {
    required this.reachSettled,
    required this.backUp,
    required this.canEdit,
  });

  final DocumentSession session;
  final Future<Reach> Function() reachSettled;
  final BackUpText backUp;
  final bool Function() canEdit;

  /// Keeps the edits for [reason] ([DocumentSession.secure]); whether
  /// they are kept: in the file or a conflict copy, or on this device
  /// while the folder can't be reached. A failed save may just have
  /// started a check of the folder, so this waits for its outcome.
  Future<bool> keep(SecureReason reason) async {
    if (await session.secure(reason)) return true;
    return await reachSettled() == Reach.unreachable;
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
    if (!canEdit()) return RestoreOutcome.notEditable;
    if (await backUp(now) is Err) return RestoreOutcome.notBackedUp;
    session.replaceAll(backup);
    return RestoreOutcome.restored;
  }
}
