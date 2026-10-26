import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../document_session.dart';
import 'changed_elsewhere_screen.dart';

/// Tells what went wrong with an open document's edits and offers its
/// ways out. Shows nothing while all is well.
class EditStateBanner extends StatelessWidget {
  const EditStateBanner(this.session, {required this.onClose, super.key});

  final DocumentSession session;

  /// Closes the editor, keeping the edits where they can be kept.
  final FutureOr<void> Function() onClose;

  @override
  Widget build(BuildContext context) => switch (session.status) {
    ChangedElsewhere() => _Banner(
      message: 'This note changed on another device or app.',
      actions: {'Compare': () => openChangedElsewhere(context, session)},
    ),
    DeletedElsewhere() => _Banner(
      message:
          'This note was deleted on another device or app. '
          'Your text is kept here; closing keeps it as a conflict.',
      actions: {'Restore with my text': session.restoreMine, 'Close': onClose},
    ),
    SaveFailed() => _Banner(
      message: 'Saving failed. Your text is kept here.',
      actions: {'Retry': session.saveNow},
    ),
    KeptAsConflict() => _Banner(
      message:
          'Your edits were kept as a conflict copy, to resolve from the '
          'notes list.',
      actions: {'Close': onClose},
    ),
    Unwritten() || InStep() || Editing() || Closed() => const SizedBox.shrink(),
  };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.actions});

  final String message;
  final Map<String, FutureOr<void> Function()> actions;

  @override
  Widget build(BuildContext context) => MaterialBanner(
    content: Text(message),
    actions: [
      for (final MapEntry(key: label, value: action) in actions.entries)
        TextButton(onPressed: action, child: Text(label)),
    ],
  );
}
