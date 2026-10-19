import 'package:flutter/material.dart';

import '../note_edit_session.dart';

/// App bar icon telling where an open note's edits are: being edited,
/// saved on this device, or saved in the note's file in the folder. While
/// they are saved on this device only, tapping it calls [onSave]. A note
/// with no file yet shows as being edited: nothing is in the folder.
class SaveIndicator extends StatelessWidget {
  const SaveIndicator(
    this.state, {
    required this.hasFile,
    required this.onSave,
    super.key,
  });

  final EditState state;

  /// Whether the note has its file in the folder.
  final bool hasFile;

  /// Saves the edits in the note's file now.
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      EditState.saved when !hasFile => (Icons.edit_outlined, 'Editing…'),
      EditState.saved => (Icons.cloud_done_outlined, 'Saved in the folder'),
      EditState.savedOnDevice => (
        Icons.save_outlined,
        'Saved on this device. Tap to save in the folder now',
      ),
      EditState.unsaved => (Icons.edit_outlined, 'Editing…'),
      EditState.changedElsewhere => (Icons.sync_problem, 'Changed elsewhere'),
      EditState.deletedElsewhere => (Icons.sync_problem, 'Deleted elsewhere'),
      EditState.saveFailed => (Icons.error_outline, 'Not saved'),
      EditState.keptAsConflict => (Icons.sync_problem, 'Kept as conflict'),
    };
    if (state == EditState.savedOnDevice) {
      return IconButton(tooltip: label, icon: Icon(icon), onPressed: onSave);
    }
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon),
      ),
    );
  }
}
