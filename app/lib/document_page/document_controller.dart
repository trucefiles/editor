import 'package:truce_core/truce_core.dart';

import 'document_session.dart';

/// Backs up [text], the open document's text now.
typedef BackUpText = Future<Result<void, StoreError>> Function(String text);

/// The open document's view model: whether its edits are kept as the
/// user leaves, and backups restored into it. No UI.
final class DocumentController {
  /// [reachSettled]: the reach of the document's folder once a running
  /// check of it is over. [backUp]: backs up the document's text.
  DocumentController(
    this.session, {
    required this.reachSettled,
    required this.backUp,
  });

  final DocumentSession session;
  final Future<Reach> Function() reachSettled;
  final BackUpText backUp;

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
  /// one edit undo takes back; first the text now is backed up. Whether
  /// it was put there: not if that backup failed.
  Future<bool> restore(String backup) async {
    if (await backUp(session.text) is Err) return false;
    session.replaceAll(backup);
    return true;
  }
}
