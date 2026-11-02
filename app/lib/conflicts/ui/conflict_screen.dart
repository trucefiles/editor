import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../versions/merge_outcome.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/resolve_error_text.dart';
import '../../versions/ui/unreachable_wait.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/ui/version_content.dart';
import '../conflict_controller.dart';

/// How a conflict screen ended, to tell where the user lands: [text], as a
/// [notice] that stays until dismissed (how a merge went) or a short hint.
typedef ConflictOutcome = ({String text, bool notice});

/// Shows both versions of a conflicting file side by side; the user
/// keeps one, or both merged where the file's type merges. Several
/// conflict copies are resolved one by one, oldest first. Closes once no
/// copy is left, with the outcome to tell as its result; what it tells
/// meanwhile stays on this screen.
class ConflictScreen extends ConsumerStatefulWidget {
  const ConflictScreen(this.initial, {super.key});

  final FolderConflict initial;

  @override
  ConsumerState<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends ConsumerState<ConflictScreen> {
  /// This screen's own messenger: what it tells goes away with it.
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  ConflictController get _controller =>
      ref.read(conflictProvider(widget.initial).notifier);

  Future<void> _keep(VersionSide side) => _resolve(switch (side) {
    VersionSide.current => const KeepCurrent(),
    VersionSide.other => const KeepOther(),
  });

  /// Keeps [merged], both versions as one.
  Future<void> _merge(MergedSides merged) =>
      _resolve(KeepMerged(merged.bytes), merged: merged);

  /// Keeps [choice]; [merged]: the merge it keeps, if it is one.
  Future<void> _resolve(Resolution choice, {MergedSides? merged}) async {
    final answer = await _controller.keep(choice);
    if (!mounted || answer == null || !answer.taken) return;
    final outcome = switch ((answer.error, merged)) {
      (final error?, _) => error.text,
      (null, final merged?) => mergeOutcome(merged.lost),
      (null, null) =>
        'Conflict resolved. A backup is kept for '
            '${backupRetention.inDays} days.',
    };
    final notice = answer.error == null && merged != null;
    if (answer.done) {
      // The opener tells it, where the user lands.
      Navigator.pop<ConflictOutcome>(context, (text: outcome, notice: notice));
    } else if (notice) {
      // How the merge went; the next copy shows meanwhile.
      _messenger.currentState?.showNotice(outcome);
    } else if (answer.error != null) {
      _messenger.currentState?.showHint(outcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = ref.watch(conflictProvider(widget.initial));
    final conflict = shown.target;
    final count = conflict.conflict.copies.length;
    return ScaffoldMessenger(
      key: _messenger,
      child: _scaffold(conflict, shown, count),
    );
  }

  Widget _scaffold(FolderConflict conflict, ConflictState shown, int count) =>
      Scaffold(
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

  bool _unreachable(Folder folder) =>
      ref.watch(folderReachProvider(folder.id)) == Reach.unreachable;

  Widget _chooser(Conflict conflict, ConflictSides sides, bool busy) {
    final deleted = sides.current == null;
    return VersionChooser(
      current: ShownVersion(
        label: 'Current version',
        content: switch ((sides.current, conflict.main)) {
          (final text?, final main?) => SavedText(text, main.modified),
          _ => const DeletedFile(),
        },
        keepLabel: deleted ? 'Keep deleted' : 'Keep this',
        keptMessage: deleted
            ? 'The file stays deleted and the other version is removed. '
                  '$bothBackedUp'
            : 'The other version is removed. $bothBackedUp',
      ),
      other: ShownVersion(
        label: 'Other version',
        content: SavedText(sides.other, sides.copy.createdAt),
        keepLabel: deleted ? 'Restore' : 'Keep this',
        keptMessage: deleted
            ? 'The file is restored from this version. $bothBackedUp'
            : 'The current version is replaced by the other one. '
                  '$bothBackedUp',
      ),
      enabled: !busy,
      onKeep: _keep,
      onMerge: switch (sides.merged) {
        final merged? => () => _merge(merged),
        null => null,
      },
    );
  }
}
