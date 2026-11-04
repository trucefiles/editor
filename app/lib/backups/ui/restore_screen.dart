import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import '../../common/snack.dart';
import '../../common/store_error_text.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/resolve_error_text.dart';
import '../../versions/ui/unreachable_wait.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/ui/version_content.dart';
import '../restore_controller.dart';
import 'backup_kind_text.dart';

/// Shows a backup next to its file as it is now, in the same view as a
/// conflict; the user keeps one. Closes once a version is kept, with the
/// outcome to tell as its result.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen(this.backup, {super.key});

  final FolderBackup backup;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  Future<void> _keep(VersionSide side) async {
    final answer = await ref.read(restoreProvider(widget.backup).notifier).keep(
      switch (side) {
        VersionSide.current => const KeepCurrent(),
        VersionSide.other => const KeepOther(),
      },
    );
    if (!mounted || answer == null || !answer.taken) return;
    switch (answer.error) {
      case final error?:
        showSnack(context, error.text);
      case null:
        Navigator.pop(
          context,
          side == VersionSide.other ? 'Backup restored.' : null,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:folder, :backup) = widget.backup;
    final shown = ref.watch(restoreProvider(widget.backup));
    return Scaffold(
      appBar: compareAppBar(
        folder: folder,
        file: backup.filePath,
        reason: 'Backup · ${backup.kind.text}',
      ),
      body: Column(
        children: [
          UnreachableBanner(folder, message: waitMessage),
          Expanded(
            child: switch (shown) {
              CompareLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              CompareLoadFailed(:final error) => Center(
                child: Text(error.text),
              ),
              CompareShowing(sides: final choice) => _chooser(
                choice,
                ref.watch(folderReachProvider(folder.id)) == Reach.unreachable,
              ),
              CompareKeeping(sides: final choice) ||
              CompareDone(sides: final choice) => _chooser(choice, true),
            },
          ),
        ],
      ),
    );
  }

  Widget _chooser(RestoreChoice choice, bool busy) {
    final current = choice.current;
    final deleted = current == null;
    return VersionChooser(
      current: ShownVersion(
        label: 'Current version',
        content: switch (current) {
          final current? => SavedText(
            versionText(current.bytes),
            current.modified,
          ),
          null => const DeletedFile(),
        },
        keepLabel: deleted ? 'Keep deleted' : 'Keep this',
        keptMessage: deleted
            ? 'The file stays deleted.'
            : 'The file stays as it is.',
      ),
      other: ShownVersion(
        label: 'Backup',
        content: SavedText(versionText(choice.bytes), choice.backup.savedAt),
        keepLabel: 'Restore',
        keptMessage: deleted
            ? 'The file is restored from this backup.'
            : 'The backup replaces the current version, which is backed '
                  'up first.',
      ),
      enabled: !busy,
      onKeep: _keep,
    );
  }
}

/// Opens [backup] to restore it; tells the outcome on the messenger of
/// [context], the screen the user comes back to.
Future<void> openRestore(BuildContext context, FolderBackup backup) async {
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await Navigator.push(
    context,
    MaterialPageRoute<String>(builder: (_) => RestoreScreen(backup)),
  );
  if (outcome != null) messenger.showHint(outcome);
}
