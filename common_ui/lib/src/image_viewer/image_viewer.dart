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
/// place, under what is drawn over its top (its top padding); zoomed in,
/// it can be moved down that far, so none of it stays hidden. [alt] is read out. It is decoded at most at the screen's
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
  late final _view = TransformationController()..addListener(_viewChanged);

  /// Moves [_view] to where a double tap, or the settling at fit, takes
  /// it.
  late final _move = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addListener(_followMove);

  Animation<Matrix4>? _movePath;

  /// Where the last double tap went down.
  Offset _tapped = Offset.zero;

  /// How many times larger than fit it shows.
  double _zoom = 1;

  bool get _zoomedIn => _zoom > 1;

  void _viewChanged() {
    final zoom = _view.value.getMaxScaleOnAxis();
    if (zoom != _zoom) setState(() => _zoom = zoom);
  }

  void _followMove() => _view.value = _movePath!.value;

  void _moveTo(Matrix4 end) {
    _movePath = Matrix4Tween(
      begin: _view.value,
      end: end,
    ).animate(CurvedAnimation(parent: _move, curve: Curves.easeOut));
    _move.forward(from: 0);
  }

  void _zoomAtTap() => _moveTo(
    tapZoomed(_view.value, spot: _tapped, zoom: ZoomableImage.tapZoom),
  );

  /// Back at fit or below, it settles at fit, so it never stays moved.
  void _settle() {
    if (!_zoomedIn && _view.value != Matrix4.identity()) {
      _moveTo(Matrix4.identity());
    }
  }

  @override
  void dispose() {
    _move.dispose();
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
        // Zoomed in, it moves down past the top as far as what is drawn
        // over it; the margin is in the picture's own size, so zoomed.
        boundaryMargin: EdgeInsets.only(
          top: _zoomedIn ? MediaQuery.paddingOf(context).top / _zoom : 0,
        ),
        // A pinch or drag takes over from a double tap's zoom.
        onInteractionStart: (_) => _move.stop(),
        onInteractionEnd: (_) => _settle(),
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
