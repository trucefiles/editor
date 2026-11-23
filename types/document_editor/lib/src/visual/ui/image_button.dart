import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_images/truce_images.dart';

import '../image_insert.dart';

/// The toolbar's Image button: picks from one of [sources]
/// ([askImageSource]); a spinner in its place while an image is made
/// ready and kept. Off while [enabled] is not.
class ImageButton extends StatelessWidget {
  const ImageButton(
    this.insert, {
    required this.sources,
    required this.enabled,
    required this.onDone,
    super.key,
  });

  final ImageInsert insert;
  final List<ImageSource> sources;
  final bool enabled;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: insert,
    builder: (context, _) => IconButton(
      tooltip: 'Image',
      icon: insert.busy
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.image_outlined),
      onPressed: enabled && !insert.busy ? () => _pressed(context) : null,
    ),
  );

  Future<void> _pressed(BuildContext context) async {
    final source = await askImageSource(context, sources);
    if (source == null || !context.mounted) return;
    await insert.from(source);
    if (context.mounted) onDone();
  }
}
