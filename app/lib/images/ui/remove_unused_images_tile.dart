import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_document_image_store/truce_document_image_store.dart';

import '../../common/snack.dart';
import '../images_wiring.dart';

/// The folder setting that removes the images no document of [folder]
/// shows any more, after the user agrees to how many.
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
    final cleanup = ref.read(imageCleanupProvider);
    setState(() => _busy = true);
    final found = await cleanup.find(widget.folder);
    final images = switch (found) {
      Ok(:final value) when value.isNotEmpty => value,
      Ok() => null,
      Err() => null,
    };
    final go = images != null && mounted && await _confirm(images.length);
    final removed = go ? await cleanup.remove(widget.folder, images) : null;
    if (!mounted) return;
    setState(() => _busy = false);
    final message = switch ((found, removed)) {
      (Err(:final error), _) => _refusedText(error),
      (Ok(value: []), _) => 'No unused images.',
      (_, final removed?) =>
        removed == 1 ? 'Removed 1 image.' : 'Removed $removed images.',
      _ => null,
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
