import 'package:flutter/material.dart';

/// Shows [image] full screen, zoomed by a pinch or the mouse wheel and
/// moved by a drag; Back, Esc (the app's, as for every page) or the close
/// button go back. [alt] is read out.
Future<void> showImageViewer(
  BuildContext context,
  ImageProvider image, {
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

  final ImageProvider image;
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
/// [maxZoom] and moved by a drag. [alt] is read out.
class ZoomableImage extends StatelessWidget {
  const ZoomableImage(this.image, {required this.alt, super.key});

  final ImageProvider image;
  final String alt;

  /// How far it zooms in.
  static const maxZoom = 8.0;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
    maxScale: maxZoom,
    child: SizedBox.expand(
      child: Image(
        image: image,
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
