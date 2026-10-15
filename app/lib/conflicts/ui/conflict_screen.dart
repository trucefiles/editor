import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../folders/ui/folder_badge.dart';
import '../conflict_controller.dart';
import '../conflict_sides.dart';
import '../folder_conflicts.dart';
import 'version_comparison.dart';
import 'version_pane.dart';

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

  Future<void> _keep(Resolution resolution) async {
    final conflict = ref.read(conflictProvider(widget.initial)).conflict;
    if (!await _confirm(conflict, resolution)) return;
    final kept = await _controller.keep(resolution);
    if (!mounted) return;
    final outcome = switch (kept.error) {
      final error? => _resolveText(error),
      null => 'Conflict resolved. A backup is kept for 7 days.',
    };
    if (kept.done) {
      // The opener tells it, where the user lands.
      Navigator.pop(context, outcome);
    } else if (kept.error != null) {
      showSnack(context, outcome);
    }
  }

  Future<bool> _confirm(FolderConflict conflict, Resolution resolution) async {
    final orphaned = conflict.conflict.isOrphaned;
    final message = switch (resolution) {
      KeepCurrent() when orphaned =>
        'The note stays deleted and the other version is removed.',
      KeepCurrent() => 'The other version is removed.',
      KeepOther() when orphaned => 'The note is restored from this version.',
      KeepOther() => 'The current version is replaced by the other one.',
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keep this version?'),
        content: Text(
          '$message A backup of both stays on this device for 7 days.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keep'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static String _resolveText(ResolveError error) => switch (error) {
    ResolveError.changedSinceScan =>
      'The files changed in the meantime. Please check again.',
    ResolveError.backupFailed => 'No backup could be made, so nothing changed.',
    ResolveError.accessDenied => 'The app has no access to this folder.',
    ResolveError.ioFailure => 'The files could not be written.',
  };

  @override
  Widget build(BuildContext context) {
    final ConflictState(:conflict, :sides, :busy) = ref.watch(
      conflictProvider(widget.initial),
    );
    final count = conflict.conflict.copies.length;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflict.conflict.mainPath.name,
              overflow: TextOverflow.ellipsis,
            ),
            FolderBadge(conflict.folder, file: conflict.conflict.mainPath),
          ],
        ),
        bottom: count > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Text('$count other versions, oldest first'),
              )
            : null,
      ),
      body: switch (sides) {
        Err(:final error) => Center(child: Text(error.text)),
        Ok(value: final sides) => _Comparison(
          conflict: conflict.conflict,
          sides: sides,
          enabled: !busy,
          onKeep: _keep,
        ),
        null => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.conflict,
    required this.sides,
    required this.enabled,
    required this.onKeep,
  });

  final Conflict conflict;
  final ConflictSides sides;
  final bool enabled;
  final ValueChanged<Resolution> onKeep;

  @override
  Widget build(BuildContext context) {
    final current = VersionPane(
      label: 'Current version',
      modified: conflict.main?.modified,
      text: sides.current,
      compareTo: sides.other,
      keepLabel: sides.current == null ? 'Keep deleted' : 'Keep this',
      onKeep: enabled ? () => onKeep(const KeepCurrent()) : null,
    );
    final other = VersionPane(
      label: 'Other version',
      modified: sides.copy.createdAt,
      text: sides.other,
      compareTo: sides.current ?? '',
      keepLabel: sides.current == null ? 'Restore' : 'Keep this',
      onKeep: enabled ? () => onKeep(const KeepOther()) : null,
    );
    return VersionComparison(first: current, second: other);
  }
}
