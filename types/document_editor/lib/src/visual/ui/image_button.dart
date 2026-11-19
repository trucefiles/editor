import 'package:flutter/material.dart';

import '../../markdown/image_picking.dart';
import '../image_insert.dart';

/// The toolbar's Image button: with one source it picks from it at once,
/// with more it asks which first ("Choose image", "Take photo"); a
/// spinner in its place while an image is made ready and kept. Off while
/// [enabled] is not.
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

  static String _label(ImageSource source) => switch (source) {
    ImageSource.file || ImageSource.gallery => 'Choose image',
    ImageSource.camera => 'Take photo',
  };

  static IconData _icon(ImageSource source) => switch (source) {
    ImageSource.file || ImageSource.gallery => Icons.photo_library_outlined,
    ImageSource.camera => Icons.photo_camera_outlined,
  };

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
    final source = sources.length == 1 ? sources.single : await _ask(context);
    if (source == null) return;
    await insert.from(source);
    onDone();
  }

  /// Which source, from a menu at the button.
  Future<ImageSource?> _ask(BuildContext context) {
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(Offset.zero, ancestor: overlay);
    return showMenu<ImageSource>(
      context: context,
      position: RelativeRect.fromLTRB(
        at.dx,
        at.dy,
        overlay.size.width - at.dx - box.size.width,
        overlay.size.height - at.dy,
      ),
      items: [
        for (final source in sources)
          PopupMenuItem(
            value: source,
            child: ListTile(
              leading: Icon(_icon(source)),
              title: Text(_label(source)),
            ),
          ),
      ],
    );
  }
}
