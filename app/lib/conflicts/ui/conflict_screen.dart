import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../../folders/folder_services.dart';
import '../../scan/folder_scans_controller.dart';
import '../conflict_sides.dart';
import '../folder_conflicts.dart';
import 'version_pane.dart';

/// Shows both versions of a conflicting note side by side; the user keeps
/// one. Several conflict copies are resolved one by one, oldest first.
class ConflictScreen extends ConsumerStatefulWidget {
  const ConflictScreen(this.initial, {super.key});

  final FolderConflict initial;

  @override
  ConsumerState<ConflictScreen> createState() => _ConflictScreenState();
}

class _ConflictScreenState extends ConsumerState<ConflictScreen> {
  late FolderConflict _conflict = widget.initial;
  ConflictSides? _sides;
  String? _error;
  bool _busy = false;

  FolderServices get _services =>
      ref.read(folderServicesProvider(_conflict.folder.location));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await ConflictSides.load(_services, _conflict.conflict);
    if (!mounted) return;
    setState(() {
      switch (loaded) {
        case Ok(:final value):
          _sides = value;
          _error = null;
        case Err(:final error):
          _error = error.text;
      }
    });
  }

  Future<void> _keep(Resolution resolution) async {
    final sides = _sides;
    if (sides == null || !await _confirm(resolution)) return;
    setState(() => _busy = true);
    final resolved = await _services.conflicts.resolve(
      _conflict.conflict,
      sides.copy,
      resolution,
    );
    await ref.read(folderScansProvider.notifier).refresh();
    if (!mounted) return;
    setState(() => _busy = false);
    final next = ref
        .read(folderScansProvider)
        .value
        ?.conflicts
        .forNote(_conflict.key);
    if (resolved case Err(:final error)) {
      showSnack(context, _resolveText(error));
    } else if (next == null) {
      showSnack(context, 'Conflict resolved. A backup is kept for 7 days.');
    }
    if (next == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _conflict = next;
      _sides = null;
    });
    await _load();
  }

  Future<bool> _confirm(Resolution resolution) async {
    final orphaned = _conflict.conflict.isOrphaned;
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
    final conflict = _conflict.conflict;
    final count = conflict.copies.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(conflict.mainPath.name),
        bottom: count > 1
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Text('$count other versions, oldest first'),
              )
            : null,
      ),
      body: switch ((_sides, _error)) {
        (_, final error?) => Center(child: Text(error)),
        (final sides?, _) => _Comparison(
          conflict: conflict,
          sides: sides,
          enabled: !_busy,
          onKeep: _keep,
        ),
        _ => const Center(child: CircularProgressIndicator()),
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

  /// Below this width the versions are stacked instead of side by side.
  static const _sideBySideWidth = 700.0;

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
    return LayoutBuilder(
      builder: (context, constraints) => Flex(
        direction: constraints.maxWidth >= _sideBySideWidth
            ? Axis.horizontal
            : Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: current),
          const VerticalDivider(width: 1),
          Expanded(child: other),
        ],
      ),
    );
  }
}
