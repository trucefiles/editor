import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../file_controller.dart';
import 'changed_elsewhere_screen.dart';

/// Tells what went wrong with an open file's edits and offers its
/// ways out. Shows nothing while all is well.
class EditStateBanner extends StatelessWidget {
  const EditStateBanner(this.controller, {required this.onClose, super.key});

  /// The open file's view model.
  final FileController controller;

  FileSession get _session => controller.session;

  /// Closes the editor, keeping the edits where they can be kept.
  final FutureOr<void> Function() onClose;

  @override
  Widget build(BuildContext context) => switch (_session.status) {
    ChangedElsewhere() => _Banner(
      message: 'This file changed on another device or app.',
      actions: {'Compare': () => openChangedElsewhere(context, controller)},
    ),
    DeletedElsewhere() => _Banner(
      message:
          'This file was deleted on another device or app. '
          'The text is kept here; closing keeps it as a conflict.',
      actions: {
        'Restore with this text': _session.restoreMine,
        'Close': onClose,
      },
    ),
    SaveFailed() => _Banner(
      message: 'Saving failed. The text is kept here.',
      actions: {'Retry': _session.saveNow},
    ),
    KeptAsConflict() => _Banner(
      message:
          'The edits were kept as a conflict copy, to resolve from the '
          'files list.',
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
