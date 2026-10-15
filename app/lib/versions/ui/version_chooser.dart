import 'package:flutter/material.dart';

import 'keep_version_dialog.dart';
import 'version_comparison.dart';
import 'version_pane.dart';

/// Which of the two versions the user keeps.
enum VersionSide {
  /// The note's file as it is in the folder.
  current,

  /// The version that clashes with it.
  other,
}

/// One of the two versions the user picks from.
final class ShownVersion {
  const ShownVersion({
    required this.label,
    required this.text,
    required this.keepLabel,
    required this.keptMessage,
    this.modified,
  });

  final String label;

  /// `null` if this version is a deleted file.
  final String? text;

  final String keepLabel;

  /// What keeping this version does, including which backup is kept
  /// (e.g. [bothBackedUp]), to confirm it.
  final String keptMessage;

  final DateTime? modified;
}

/// Tells that both versions are backed up before one is kept.
const bothBackedUp = 'A backup of both stays on this device for 7 days.';

/// The one view for every clash between two versions of a note: shows both
/// and asks before keeping one. The owner of [onKeep] makes the backups
/// its versions' [ShownVersion.keptMessage] tells of, before it changes
/// anything.
class VersionChooser extends StatelessWidget {
  const VersionChooser({
    required this.current,
    required this.other,
    required this.enabled,
    required this.onKeep,
    super.key,
  });

  final ShownVersion current;
  final ShownVersion other;

  /// `false` while a choice is being carried out.
  final bool enabled;

  /// Called once the user confirmed keeping a side.
  final ValueChanged<VersionSide> onKeep;

  Future<void> _keep(BuildContext context, VersionSide side) async {
    final kept = side == VersionSide.current ? current : other;
    final confirmed = await confirmKeepVersion(context, kept.keptMessage);
    if (confirmed) onKeep(side);
  }

  Widget _pane(BuildContext context, VersionSide side) {
    final (shown, compared) = side == VersionSide.current
        ? (current, other)
        : (other, current);
    return VersionPane(
      label: shown.label,
      modified: shown.modified,
      text: shown.text,
      compareTo: compared.text ?? '',
      keepLabel: shown.keepLabel,
      onKeep: enabled ? () => _keep(context, side) : null,
    );
  }

  @override
  Widget build(BuildContext context) => VersionComparison(
    first: _pane(context, VersionSide.current),
    second: _pane(context, VersionSide.other),
  );
}
