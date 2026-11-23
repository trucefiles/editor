import 'package:flutter/material.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_image_file/truce_image_file.dart';
import 'package:truce_images/truce_images.dart';

import 'content_image.dart';
import 'image_file_facts.dart';
import 'new_image.dart';

/// Pictures with how they show: a card shows the picture cut to its
/// shape, their page and a comparison show it whole to zoom; a new one
/// is chosen or taken by [picking].
final class ImageViewType extends ImageFileType implements ViewType {
  const ImageViewType(this._picking);

  final ImagePicking _picking;

  @override
  IconData get icon => Icons.image_outlined;

  /// Centered on the page; zoomed in, it moves out from under its
  /// banners by a drag.
  @override
  bool get underBanners => true;

  /// Decoded no larger than the zoomable view asks.
  @override
  Widget view(ShownContent content, {required String label}) =>
      ZoomableImage((size) => ContentImage(content, size: size), alt: label);

  @override
  Widget thumbnail(ShownContent content, {required String label}) =>
      ImageThumbnail(content, label: label);

  @override
  Future<List<FileFact>> facts(ShownContent content) => imageFileFacts(content);

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
              size: Covering(
                (constraints.maxWidth * pixels).ceil(),
                (constraints.maxHeight * pixels).ceil(),
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
