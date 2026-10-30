import 'package:flutter/material.dart';

import 'keep_version_dialog.dart';
import 'version_comparison.dart';
import 'version_content.dart';
import 'version_pane.dart';

/// Which of the two versions the user keeps.
enum VersionSide {
  /// The document's file as it is in the folder.
  current,

  /// The version that clashes with it.
  other,
}

/// One of the two versions the user picks from.
final class ShownVersion {
  const ShownVersion({
    required this.label,
    required this.content,
    required this.keepLabel,
    required this.keptMessage,
  });

  final String label;
  final VersionContent content;

  final String keepLabel;

  /// What keeping this version does, including which backup is kept
  /// (e.g. that both are backed up), to confirm it.
  final String keptMessage;
}

/// The one view for every clash between two versions of a document: shows both
/// and asks before keeping one. The current version is the base of the
/// diff: lines only it has show as added, lines only the other has as
/// removed, each on its own side. The owner of [onKeep] makes the backups
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
    final (shown, compared, ownLines) = switch (side) {
      VersionSide.current => (current, other, OwnLines.added),
      VersionSide.other => (other, current, OwnLines.removed),
    };
    return VersionPane(
      label: shown.label,
      content: shown.content,
      compareTo: compared.content.text ?? '',
      ownLines: ownLines,
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
