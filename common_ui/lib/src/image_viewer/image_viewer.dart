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

  static const _maxZoom = 8.0;

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
      body: InteractiveViewer(
        maxScale: _maxZoom,
        child: SizedBox.expand(
          child: Image(image: image, semanticLabel: alt, fit: BoxFit.contain),
        ),
      ),
    ),
  );
}
