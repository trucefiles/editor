import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../reach/folder_reach_controller.dart';
import '../../reach/ui/unreachable_banner.dart';
import '../../versions/resolve_error_text.dart';
import '../../versions/ui/compare_app_bar.dart';
import '../../versions/ui/unreachable_wait.dart';
import '../../versions/ui/version_chooser.dart';
import '../../versions/version_text.dart';
import '../all_backups.dart';
import '../backup_retention.dart';
import '../restore_controller.dart';
import 'backup_kind_text.dart';

/// Shows a backup next to its note as it is now, in the same view as a
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
    final kept = await ref.read(restoreProvider(widget.backup).notifier).keep(
      switch (side) {
        VersionSide.current => const KeepCurrent(),
        VersionSide.other => const KeepOther(),
      },
    );
    if (!mounted) return;
    switch (kept) {
      case Ok():
        Navigator.pop(
          context,
          side == VersionSide.other ? 'Backup restored.' : null,
        );
      case Err(:final error):
        showSnack(context, error.text);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (:folder, :backup) = widget.backup;
    final RestoreState(:choice, :busy) = ref.watch(
      restoreProvider(widget.backup),
    );
    return Scaffold(
      appBar: compareAppBar(
        folder: folder,
        file: backup.filePath,
        note: 'Backup: ${backup.kind.text}',
      ),
      body: Column(
        children: [
          UnreachableBanner(folder, message: waitMessage),
          Expanded(
            child: switch (choice) {
              Err(:final error) => Center(child: Text(error.text)),
              Ok(value: final choice) => _chooser(
                choice,
                busy ||
                    ref.watch(folderReachProvider(folder.location)) ==
                        Reach.unreachable,
              ),
              null => const Center(child: CircularProgressIndicator()),
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
        modified: current?.modified,
        text: current == null ? null : versionText(current.bytes),
        keepLabel: deleted ? 'Keep deleted' : 'Keep this',
        keptMessage: deleted
            ? 'The note stays deleted.'
            : 'The note stays as it is.',
      ),
      other: ShownVersion(
        label: 'Backup',
        modified: choice.backup.savedAt,
        text: versionText(choice.bytes),
        keepLabel: 'Restore',
        keptMessage: deleted
            ? 'The note is restored from this backup.'
            : 'The current version is replaced by the backup. A backup of '
                  'the current version stays on this device for '
                  '${backupRetention.inDays} days.',
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
