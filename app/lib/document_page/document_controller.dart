import 'package:truce_core/truce_core.dart';

import 'document_session.dart';

/// The open document's view model: whether its edits are kept as the
/// user leaves. No UI.
final class DocumentController {
  /// [reachSettled]: the reach of the document's folder once a running
  /// check of it is over.
  DocumentController(this.session, {required this.reachSettled});

  final DocumentSession session;
  final Future<Reach> Function() reachSettled;

  /// Keeps the edits for [reason] ([DocumentSession.secure]); whether
  /// they are kept: in the file or a conflict copy, or on this device
  /// while the folder can't be reached. A failed save may just have
  /// started a check of the folder, so this waits for its outcome.
  Future<bool> keep(SecureReason reason) async {
    if (await session.secure(reason)) return true;
    return await reachSettled() == Reach.unreachable;
  }
}
