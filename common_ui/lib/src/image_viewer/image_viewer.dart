import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'bytes_image.dart';

/// Shows [image] full screen, zoomed by a pinch or the mouse wheel and
/// moved by a drag; Back, Esc (the app's, as for every page) or the close
/// button go back. [alt] is read out.
Future<void> showImageViewer(
  BuildContext context,
  SizedImage image, {
  required String alt,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => ImageViewer(image, alt: alt),
  ),
);

/// One image full screen, on black, that zooms (see [showImageViewer]).
class ImageViewer extends StatelessWidget {
  const ImageViewer(this.image, {required this.alt, super.key});

  final SizedImage image;
  final String alt;

  @override
  Widget build(BuildContext context) => Theme(
    data: ThemeData.dark(),
    child: Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        leading: const CloseButton(),
      ),
      body: ZoomableImage(image, alt: alt),
    ),
  );
}

/// [image] as large as fits, zoomed by a pinch or the mouse wheel up to
/// [maxZoom] and moved by a drag. [alt] is read out. It is decoded at
/// most at the screen's size times [sharpZoom], and never past
/// [DecodeSize.largestSide] a side, so a huge picture never fills memory;
/// deeper zoom gets a little soft.
class ZoomableImage extends StatelessWidget {
  const ZoomableImage(this.image, {required this.alt, super.key});

  final SizedImage image;
  final String alt;

  /// How far it zooms in.
  static const maxZoom = 8.0;

  /// How far it zooms in and stays sharp.
  static const sharpZoom = 3.0;

  /// The size it is decoded at most on the screen of [context].
  static Within sizeOn(BuildContext context) {
    final screen =
        MediaQuery.sizeOf(context) *
        MediaQuery.devicePixelRatioOf(context) *
        sharpZoom;
    int bounded(double side) => math.min(side.ceil(), DecodeSize.largestSide);
    return Within(bounded(screen.width), bounded(screen.height));
  }

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    maxScale: maxZoom,
    child: SizedBox.expand(
      child: Image(
        image: image(sizeOn(context)),
        semanticLabel: alt,
        fit: BoxFit.contain,
        errorBuilder: (context, _, _) => Center(
          child: Text(
            "This image can't be shown.",
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    ),
  );
}
