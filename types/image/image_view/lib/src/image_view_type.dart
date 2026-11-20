import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_image_file/truce_image_file.dart';
import 'package:truce_images/truce_images.dart';

import 'content_image.dart';
import 'new_image.dart';

/// Pictures with how they show: a card shows the picture cut to its
/// shape, their page and a comparison show it whole to zoom; a new one
/// is chosen or taken by [picking].
final class ImageViewType extends ImageFileType implements ViewType {
  const ImageViewType(this._picking);

  final ImagePicking _picking;

  @override
  IconData get icon => Icons.image_outlined;

  /// Decoded at most at the screen's size times the zoom limit, so a
  /// zoomed picture stays sharp while a huge one never fills memory.
  @override
  Widget view(ShownContent content, {required String label}) => Builder(
    builder: (context) {
      final screen =
          MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
      final most = screen * ZoomableImage.maxZoom;
      return ZoomableImage(
        ResizeImage(
          ContentImage(content),
          width: most.width.ceil(),
          height: most.height.ceil(),
          policy: ResizeImagePolicy.fit,
          allowUpscaling: false,
        ),
        alt: label,
      );
    },
  );

  @override
  Widget thumbnail(ShownContent content, {required String label}) =>
      ImageThumbnail(content, label: label);

  @override
  Future<NewContent?> makeNew(
    BuildContext context,
    NewFileKind kind, {
    required void Function(String message) hint,
  }) => askForImage(context, _picking, hint: hint);
}

/// [content]'s picture in a fixed shape, cut to fill it, so a card's
/// height is known before the picture is read; decoded only as large as
/// it shows.
class ImageThumbnail extends StatelessWidget {
  const ImageThumbnail(this.content, {required this.label, super.key});

  final ShownContent content;
  final String label;

  /// Width to height.
  static const shape = 4 / 3;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: AspectRatio(
      aspectRatio: shape,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth * MediaQuery.devicePixelRatioOf(context);
          return Image(
            image: ResizeImage(
              ContentImage(content),
              width: width.ceil(),
              allowUpscaling: false,
            ),
            semanticLabel: label,
            fit: BoxFit.cover,
            errorBuilder: (context, _, _) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(child: Icon(Icons.broken_image_outlined)),
            ),
          );
        },
      ),
    ),
  );
}
