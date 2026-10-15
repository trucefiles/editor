import 'dart:async';

import 'package:flutter/material.dart';

import '../note_edit_session.dart';

/// Tells what went wrong with an open note's edits and offers the
/// session's ways out. Shows nothing while all is well.
class EditStateBanner extends StatelessWidget {
  const EditStateBanner(this.session, {required this.onClose, super.key});

  final NoteEditSession session;

  /// Closes the editor, keeping the edits where they can be kept.
  final FutureOr<void> Function() onClose;

  @override
  Widget build(BuildContext context) => switch (session.state) {
    EditState.saved ||
    EditState.savedOnDevice ||
    EditState.unsaved => const SizedBox.shrink(),
    EditState.changedElsewhere => _Banner(
      message: 'This note changed on another device or app.',
      actions: {
        'Load theirs': session.loadTheirs,
        'Keep mine': session.keepMine,
      },
    ),
    EditState.deletedElsewhere => _Banner(
      message:
          'This note was deleted on another device or app. '
          'Your text is kept here; closing keeps it as a conflict.',
      actions: {'Restore with my text': session.restoreMine, 'Close': onClose},
    ),
    EditState.saveFailed => _Banner(
      message: 'Saving failed. Your text is kept here.',
      actions: {'Retry': session.flush},
    ),
    EditState.keptAsConflict => _Banner(
      message:
          'Your edits were kept as a conflict copy, to resolve from the '
          'notes list.',
      actions: {'Close': onClose},
    ),
  };
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.actions});

  final String message;
  final Map<String, FutureOr<void> Function()> actions;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: [
        for (final MapEntry(key: label, value: action) in actions.entries)
          TextButton(onPressed: action, child: Text(label)),
      ],
    );
  }
}
