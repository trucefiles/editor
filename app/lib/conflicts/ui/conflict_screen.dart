import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../backups/backup_retention.dart';
import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../folders/document_folder.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../versions/resolve_error_text.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/unreachable_wait.dart';
import '../../versions/ui/version_chooser.dart';
import '../conflict_controller.dart';
import '../conflict_sides.dart';
import '../folder_conflicts.dart';

/// Shows both versions of a conflicting document side by side; the user keeps
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
    final answer = await _controller.keep(switch (side) {
      VersionSide.current => const KeepCurrent(),
      VersionSide.other => const KeepOther(),
    });
    if (!mounted || answer == null || !answer.taken) return;
    final outcome = switch (answer.error) {
      final error? => error.text,
      null =>
        'Conflict resolved. A backup is kept for '
            '${backupRetention.inDays} days.',
    };
    if (answer.done) {
      // The opener tells it, where the user lands.
      Navigator.pop(context, outcome);
    } else if (answer.error != null) {
      showSnack(context, outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = ref.watch(conflictProvider(widget.initial));
    final conflict = shown.target;
    final count = conflict.conflict.copies.length;
    return Scaffold(
      appBar: compareAppBar(
        folder: conflict.folder,
        file: conflict.conflict.mainPath,
        reason: count > 1 ? '$count other versions, oldest first' : null,
      ),
      body: Column(
        children: [
          UnreachableBanner(conflict.folder, message: waitMessage),
          Expanded(
            child: switch (shown) {
              CompareLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              CompareLoadFailed(:final error) => Center(
                child: Text(error.text),
              ),
              CompareShowing(:final sides) => _chooser(
                conflict.conflict,
                sides,
                _unreachable(conflict.folder),
              ),
              CompareKeeping(:final sides) || CompareDone(:final sides) =>
                _chooser(conflict.conflict, sides, true),
            },
          ),
        ],
      ),
    );
  }

  bool _unreachable(DocumentFolder folder) =>
      ref.watch(folderReachProvider(folder.location)) == Reach.unreachable;

  Widget _chooser(Conflict conflict, ConflictSides sides, bool busy) {
    final deleted = sides.current == null;
    return VersionChooser(
      current: ShownVersion(
        label: 'Current version',
        modified: conflict.main?.modified,
        text: sides.current,
        keepLabel: deleted ? 'Keep deleted' : 'Keep this',
        keptMessage: deleted
            ? 'The document stays deleted and the other version is removed. '
                  '$bothBackedUp'
            : 'The other version is removed. $bothBackedUp',
      ),
      other: ShownVersion(
        label: 'Other version',
        modified: sides.copy.createdAt,
        text: sides.other,
        keepLabel: deleted ? 'Restore' : 'Keep this',
        keptMessage: deleted
            ? 'The document is restored from this version. $bothBackedUp'
            : 'The current version is replaced by the other one. '
                  '$bothBackedUp',
      ),
      enabled: !busy,
      onKeep: _keep,
    );
  }
}
