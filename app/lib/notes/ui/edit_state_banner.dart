import 'dart:async';

import 'package:flutter/material.dart';

import '../note_edit_session.dart';
import '../open_note.dart';
import 'changed_elsewhere_screen.dart';

/// Tells what went wrong with an open note's edits and offers its ways
/// out. Shows nothing while all is well.
class EditStateBanner extends StatelessWidget {
  const EditStateBanner(this.note, {required this.onClose, super.key});

  final OpenNote note;

  /// Closes the editor, keeping the edits where they can be kept.
  final FutureOr<void> Function() onClose;

  @override
  Widget build(BuildContext context) => switch ((note.state, note.session)) {
    (EditState.changedElsewhere, final session?) => _Banner(
      message: 'This note changed on another device or app.',
      actions: {'Compare': () => openChangedElsewhere(context, session)},
    ),
    (EditState.deletedElsewhere, final session?) => _Banner(
      message:
          'This note was deleted on another device or app. '
          'Your text is kept here; closing keeps it as a conflict.',
      actions: {'Restore with my text': session.restoreMine, 'Close': onClose},
    ),
    (EditState.saveFailed, _) => _Banner(
      message: 'Saving failed. Your text is kept here.',
      actions: {'Retry': note.flush},
    ),
    (EditState.keptAsConflict, _) => _Banner(
      message:
          'Your edits were kept as a conflict copy, to resolve from the '
          'notes list.',
      actions: {'Close': onClose},
    ),
    _ => const SizedBox.shrink(),
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
