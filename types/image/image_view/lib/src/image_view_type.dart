import 'dart:math' as math;

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

  /// How far a shown picture zooms in and stays sharp: it is decoded at
  /// most at the screen's size times this, so a huge one never fills
  /// memory; deeper zoom gets a little soft.
  static const sharpZoom = 3.0;

  /// The most pixels a shown picture is decoded at on each side, on any
  /// screen (about 64 MB at most).
  static const largestSide = 4096.0;

  /// Decoded at most at the screen's size times [sharpZoom], and never
  /// past [largestSide].
  @override
  Widget view(ShownContent content, {required String label}) => Builder(
    builder: (context) {
      final screen =
          MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
      final most = (screen * sharpZoom).bounded(largestSide);
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
          final pixels = MediaQuery.devicePixelRatioOf(context);
          return Image(
            image: ContentImage(
              content,
              cover: (
                width: (constraints.maxWidth * pixels).ceil(),
                height: (constraints.maxHeight * pixels).ceil(),
              ),
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

extension on Size {
  /// This size, each side at most [side].
  Size bounded(double side) =>
      Size(math.min(width, side), math.min(height, side));
}
