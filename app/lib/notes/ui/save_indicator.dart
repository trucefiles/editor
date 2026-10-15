import 'package:flutter/material.dart';

import '../note_edit_session.dart';

/// App bar icon telling where an open note's edits are: being edited,
/// saved on this device, or saved in the note's file in the folder.
class SaveIndicator extends StatelessWidget {
  const SaveIndicator(this.state, {super.key});

  final EditState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      EditState.saved => (Icons.cloud_done_outlined, 'Saved in the folder'),
      EditState.savedOnDevice => (Icons.save_outlined, 'Saved on this device'),
      EditState.unsaved => (Icons.edit_outlined, 'Editing…'),
      EditState.changedElsewhere => (Icons.sync_problem, 'Changed elsewhere'),
      EditState.deletedElsewhere => (Icons.sync_problem, 'Deleted elsewhere'),
      EditState.saveFailed => (Icons.error_outline, 'Not saved'),
      EditState.keptAsConflict => (Icons.sync_problem, 'Kept as conflict'),
    };
    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(icon),
      ),
    );
  }
}
