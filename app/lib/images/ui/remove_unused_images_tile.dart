import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../../common/snack.dart';
import '../image_cleanup_flow.dart';
import '../images_wiring.dart';

/// The folder setting that removes the images no document of [folder]
/// shows any more, after the user agrees to how many
/// ([cleanUpUnusedImages]): it shows the flow and its outcome.
class RemoveUnusedImagesTile extends ConsumerStatefulWidget {
  const RemoveUnusedImagesTile(this.folder, {super.key});

  final FolderId folder;

  @override
  ConsumerState<RemoveUnusedImagesTile> createState() =>
      _RemoveUnusedImagesTileState();
}

class _RemoveUnusedImagesTileState
    extends ConsumerState<RemoveUnusedImagesTile> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    final outcome = await cleanUpUnusedImages(
      ref.read(imageCleanupProvider),
      widget.folder,
      confirm: (count) async => mounted && await _confirm(count),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch (outcome) {
      CleanupNotRun(:final why) => _refusedText(why),
      NoneUnused() => 'No unused images.',
      UnusedRemoved(count: 1) => 'Removed 1 image.',
      UnusedRemoved(:final count) => 'Removed $count images.',
      UnusedKept() => null,
    };
    if (message != null) showSnack(context, message);
  }

  Future<bool> _confirm(int count) async {
    final images = count == 1 ? '1 unused image' : '$count unused images';
    final go = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $images?'),
        content: const Text(
          'No document in this folder shows them. '
          'You can bring them back for 7 days by restoring a document '
          'that showed them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return go ?? false;
  }

  static String _refusedText(CleanupRefused refused) => switch (refused) {
    CleanupRefused.notAllRead =>
      "Couldn't read every document, so nothing was removed. "
          'Please try again later.',
    CleanupRefused.storeUnreadable =>
      "Couldn't read the folder's images. Please try again later.",
  };

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: const Text('Remove unused images'),
    subtitle: const Text('Images no document here shows any more'),
    trailing: _busy
        ? const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
    onTap: _busy ? null : _run,
  );
}
