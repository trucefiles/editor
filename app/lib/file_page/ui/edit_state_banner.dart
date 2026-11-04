import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
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
  Widget build(BuildContext context) => switch (_session.state) {
    // Read only wins: editing has ended, so nothing else can be done.
    final Stopped stopped => _Banner(
      message: _stoppedText(stopped),
      actions: {'Copy text': () => _copy(context, stopped.text)},
    ),
    Running() || Ended() => _ofStatus(context),
  };

  /// Why the file is read only now, and whether its edits are kept.
  static String _stoppedText(Stopped stopped) => switch (stopped) {
    Stopped(cause: StopCause.folderGone) =>
      "This file's folder was removed from the app, so you can't edit it "
          'anymore. Copy any recent edits before you close it.',
    Stopped(kept: true) =>
      'Something went wrong, so this file is read-only for now. Your edits '
          'are safe on this device and get saved the next time you start '
          'the app.',
    Stopped(kept: false) =>
      'Something went wrong, so this file is read-only. Your latest edits '
          "couldn't be saved: copy them before you close it.",
    // Whether the device keeps them is told as soon as it is known.
    Stopped(kept: null) =>
      'Something went wrong, so this file is read-only for now.',
  };

  /// Puts [text], the latest edits, on the clipboard, so they can be kept
  /// elsewhere.
  static Future<void> _copy(BuildContext context, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) showSnack(context, 'Copied.');
  }

  Widget _ofStatus(BuildContext context) => switch (_session.status) {
    ChangedElsewhere() => _Banner(
      message: 'This file changed in the folder while you were editing.',
      actions: {'Compare': () => openChangedElsewhere(context, controller)},
    ),
    DeletedElsewhere() => _Banner(
      message:
          'This file was deleted in the folder. Your text is still open in '
          'the app.',
      actions: {
        'Recreate with my text': _session.restoreMine,
        'Save as conflict copy and close': onClose,
      },
    ),
    SaveFailed() => _Banner(
      message: "Couldn't save. Your text is still here.",
      actions: {'Retry': _session.saveNow},
    ),
    KeptAsConflict() => _Banner(
      message:
          "Your edits were saved as a conflict copy. You'll find it under "
          'Conflicts on Home.',
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
