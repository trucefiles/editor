import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_core/truce_core.dart';

import '../document_controller.dart';
import '../document_session.dart';
import 'changed_elsewhere_screen.dart';

/// Tells what went wrong with an open document's edits and offers its
/// ways out. Shows nothing while all is well.
class EditStateBanner extends StatelessWidget {
  const EditStateBanner(this.controller, {required this.onClose, super.key});

  /// The open document's view model.
  final DocumentController controller;

  DocumentSession get _session => controller.session;

  /// Closes the editor, keeping the edits where they can be kept.
  final FutureOr<void> Function() onClose;

  @override
  Widget build(BuildContext context) => switch (_session.status) {
    ChangedElsewhere() => _Banner(
      message: 'This document changed on another device or app.',
      actions: {'Compare': () => openChangedElsewhere(context, controller)},
    ),
    DeletedElsewhere() => _Banner(
      message:
          'This document was deleted on another device or app. '
          'Your text is kept here; closing keeps it as a conflict.',
      actions: {'Restore with my text': _session.restoreMine, 'Close': onClose},
    ),
    SaveFailed() => _Banner(
      message: 'Saving failed. Your text is kept here.',
      actions: {'Retry': _session.saveNow},
    ),
    KeptAsConflict() => _Banner(
      message:
          'Your edits were kept as a conflict copy, to resolve from the '
          'documents list.',
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
