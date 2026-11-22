import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../zoom/zooms_itself.dart';
import 'bytes_image.dart';
import 'tap_zoom.dart';

/// Shows [image] full screen, zoomed by a pinch, the mouse wheel or a
/// double tap and moved by a drag; Back, Esc (the app's, as for every
/// page) or the close button go back. [alt] is read out.
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
/// [maxZoom] and moved by a drag; a double tap or double click zooms in
/// [tapZoom] times on that spot, and the next one goes back to fit. The
/// pinch and wheel on it are its own ([ZoomsItself]). At fit it stays in
/// place: what is drawn over its top (its top padding) only hides a
/// corner of it. [alt] is read out. It is decoded at most at the screen's
/// size times [sharpZoom], and never past [DecodeSize.largestSide] a
/// side, so a huge picture never fills memory; deeper zoom gets a little
/// soft.
class ZoomableImage extends StatefulWidget {
  const ZoomableImage(this.image, {required this.alt, super.key});

  final SizedImage image;
  final String alt;

  /// How far it zooms in.
  static const maxZoom = 8.0;

  /// How far it zooms in and stays sharp.
  static const sharpZoom = 3.0;

  /// How far a double tap zooms in.
  static const tapZoom = 2.5;

  /// The size it is decoded at most on the screen of [context].
  static Within _sizeOn(BuildContext context) {
    final screen =
        MediaQuery.sizeOf(context) *
        MediaQuery.devicePixelRatioOf(context) *
        sharpZoom;
    int bounded(double side) => math.min(side.ceil(), DecodeSize.largestSide);
    return Within(bounded(screen.width), bounded(screen.height));
  }

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage>
    with SingleTickerProviderStateMixin {
  final _view = TransformationController();

  /// Moves [_view] to where a double tap takes it.
  late final _tapZoom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addListener(_followTapZoom);

  Animation<Matrix4>? _tapZoomPath;

  /// Where the last double tap went down.
  Offset _tapped = Offset.zero;

  void _followTapZoom() => _view.value = _tapZoomPath!.value;

  void _zoomAtTap() {
    _tapZoomPath = Matrix4Tween(
      begin: _view.value,
      end: tapZoomed(_view.value, spot: _tapped, zoom: ZoomableImage.tapZoom),
    ).animate(CurvedAnimation(parent: _tapZoom, curve: Curves.easeOut));
    _tapZoom.forward(from: 0);
  }

  @override
  void dispose() {
    _tapZoom.dispose();
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZoomsItself(
    child: GestureDetector(
      onDoubleTapDown: (details) => _tapped = details.localPosition,
      onDoubleTap: _zoomAtTap,
      child: InteractiveViewer(
        transformationController: _view,
        maxScale: ZoomableImage.maxZoom,
        // A pinch or drag takes over from a double tap's zoom.
        onInteractionStart: (_) => _tapZoom.stop(),
        child: SizedBox.expand(
          child: Image(
            image: widget.image(ZoomableImage._sizeOn(context)),
            // A picture that changed stays until the new one is drawn.
            gaplessPlayback: true,
            semanticLabel: widget.alt,
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => Center(
              child: Text(
                "This image can't be shown.",
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
