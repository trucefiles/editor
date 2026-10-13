import 'package:flutter/material.dart';

import '../note_edit_session.dart';

/// App bar icon telling whether an open note's edits are saved.
class SaveIndicator extends StatelessWidget {
  const SaveIndicator(this.state, {super.key});

  final EditState state;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (state) {
      EditState.saved => (Icons.cloud_done_outlined, 'Saved'),
      EditState.unsaved => (Icons.edit_outlined, 'Saving…'),
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
