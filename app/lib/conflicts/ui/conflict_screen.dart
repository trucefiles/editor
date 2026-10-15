import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../versions/resolve_error_text.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/version_chooser.dart';
import '../conflict_controller.dart';
import '../conflict_sides.dart';
import '../folder_conflicts.dart';

/// Shows both versions of a conflicting note side by side; the user keeps
/// one. Several conflict copies are resolved one by one, oldest first.
/// Closes once no copy is left, with the outcome to tell as its result.
class ConflictScreen extends ConsumerStatefulWidget {
  const ConflictScreen(this.initial, {super.key});

  final FolderConflict initial;

  @override
  ConsumerState<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends ConsumerState<ConflictScreen> {
  ConflictController get _controller =>
      ref.read(conflictProvider(widget.initial).notifier);

  Future<void> _keep(VersionSide side) async {
    final kept = await _controller.keep(switch (side) {
      VersionSide.current => const KeepCurrent(),
      VersionSide.other => const KeepOther(),
    });
    if (!mounted) return;
    final outcome = switch (kept.error) {
      final error? => error.text,
      null => 'Conflict resolved. A backup is kept for 7 days.',
    };
    if (kept.done) {
      // The opener tells it, where the user lands.
      Navigator.pop(context, outcome);
    } else if (kept.error != null) {
      showSnack(context, outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ConflictState(:conflict, :sides, :busy) = ref.watch(
      conflictProvider(widget.initial),
    );
    final count = conflict.conflict.copies.length;
    return Scaffold(
      appBar: compareAppBar(
        folder: conflict.folder,
        file: conflict.conflict.mainPath,
        note: count > 1 ? '$count other versions, oldest first' : null,
      ),
      body: switch (sides) {
        Err(:final error) => Center(child: Text(error.text)),
        Ok(value: final sides) => _chooser(conflict.conflict, sides, busy),
        null => const Center(child: CircularProgressIndicator()),
      },
    );
  }

  Widget _chooser(Conflict conflict, ConflictSides sides, bool busy) {
    final deleted = sides.current == null;
    return VersionChooser(
      current: ShownVersion(
        label: 'Current version',
        modified: conflict.main?.modified,
        text: sides.current,
        keepLabel: deleted ? 'Keep deleted' : 'Keep this',
        keptMessage: deleted
            ? 'The note stays deleted and the other version is removed. '
                  '$bothBackedUp'
            : 'The other version is removed. $bothBackedUp',
      ),
      other: ShownVersion(
        label: 'Other version',
        modified: sides.copy.createdAt,
        text: sides.other,
        keepLabel: deleted ? 'Restore' : 'Keep this',
        keptMessage: deleted
            ? 'The note is restored from this version. $bothBackedUp'
            : 'The current version is replaced by the other one. '
                  '$bothBackedUp',
      ),
      enabled: !busy,
      onKeep: _keep,
    );
  }
}
