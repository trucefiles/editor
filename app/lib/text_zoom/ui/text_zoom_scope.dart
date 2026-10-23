import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/screen_shortcuts.dart';
import '../text_zoom.dart';
import '../text_zoom_controller.dart';
import 'pinch_to_zoom.dart';
import 'text_zoom_keys.dart';
import 'text_zoom_scale.dart';
import 'text_zoom_toast.dart';
import 'wheel_to_zoom.dart';

/// [child], the whole app, with its text at the zoom setting. On every
/// screen, the zoom keys ([textZoomKeys]), Ctrl with the mouse wheel and
/// pinching change it; each such change shows a [TextZoomToast] for a
/// moment, which stays while its slider is held.
class TextZoomScope extends ConsumerStatefulWidget {
  const TextZoomScope({required this.child, super.key});

  final Widget child;

  /// How long the toast stays after the last change.
  static const toastTime = Duration(seconds: 2);

  @override
  ConsumerState<TextZoomScope> createState() => _TextZoomScopeState();
}

class _TextZoomScopeState extends ConsumerState<TextZoomScope> {
  bool _toastShown = false;
  Timer? _hideToast;

  /// Whether the toast's slider is held.
  bool _sliding = false;

  TextZoomController get _zoom => ref.read(textZoomProvider.notifier);

  @override
  void dispose() {
    _hideToast?.cancel();
    super.dispose();
  }

  void _zoomTo(TextZoom zoom) {
    unawaited(_zoom.set(zoom));
    _showToast();
  }

  void _zoomBy(TextZoom Function(TextZoom zoom) next) {
    unawaited(_zoom.change(next));
    _showToast();
  }

  void _slide(bool sliding) {
    _sliding = sliding;
    _showToast();
  }

  /// Shows the toast, and hides it [TextZoomScope.toastTime] after the
  /// last change, once its slider isn't held.
  void _showToast() {
    _hideToast?.cancel();
    _hideToast = _sliding
        ? null
        : Timer(TextZoomScope.toastTime, () {
            if (mounted) setState(() => _toastShown = false);
          });
    if (!_toastShown) setState(() => _toastShown = true);
  }

  @override
  Widget build(BuildContext context) {
    final zoom = ref.watch(textZoomProvider).value ?? TextZoom.normal;
    return ScreenShortcuts(
      bindings: {
        for (final MapEntry(key: key, value: next) in textZoomKeys.entries)
          key: () => _zoomBy(next),
      },
      child: WheelToZoom(
        onZoom: (larger) =>
            _zoomBy((zoom) => larger ? zoom.larger : zoom.smaller),
        child: PinchToZoom(
          zoom: zoom,
          onZoom: _zoomTo,
          child: Stack(
            children: [
              TextZoomScale(zoom: zoom, child: widget.child),
              // Outside the zoom: it stays put under a finger on it. In an
              // overlay of its own, which its slider needs: the app's are
              // all inside [child].
              if (_toastShown)
                Positioned.fill(
                  child: Overlay.wrap(
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
                          child: TextZoomToast(
                            zoom: zoom,
                            onZoom: _zoomTo,
                            onSliding: _slide,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
