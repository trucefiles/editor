import 'package:flutter/material.dart';

import '../save_state.dart';

/// App bar icon telling where an open document's edits are: being
/// edited, saved on this device, or saved in its file in the folder.
/// While they are saved on this device only, tapping it calls [onSave].
/// Nothing shows where there is nothing to tell.
class SaveIndicator extends StatelessWidget {
  const SaveIndicator(this.state, {required this.onSave, super.key});

  final SaveState state;

  /// Saves the edits in the document's file now.
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => switch (state) {
    SaveState.none => const SizedBox.shrink(),
    SaveState.editing => _icon(Icons.edit_outlined, 'Editing…'),
    SaveState.onDevice => IconButton(
      tooltip: 'Saved on this device. Tap to save in the folder now',
      icon: const Icon(Icons.save_outlined),
      onPressed: onSave,
    ),
    SaveState.inFolder => _icon(
      Icons.cloud_done_outlined,
      'Saved in the folder',
    ),
  };

  static Widget _icon(IconData icon, String label) => Tooltip(
    message: label,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Icon(icon),
    ),
  );
}
