import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/screen_shortcuts.dart';
import '../text_zoom.dart';
import '../text_zoom_controller.dart';
import 'pinch_to_zoom.dart';
import 'text_zoom_keys.dart';
import 'text_zoom_scale.dart';
import 'text_zoom_toast_host.dart';
import 'wheel_to_zoom.dart';

/// [child], the whole app, with its text at the zoom setting. On every
/// screen, the zoom keys ([textZoomKeys]), Ctrl with the mouse wheel and
/// pinching change it; each such change shows the zoom for a moment
/// ([TextZoomToastHost]).
class TextZoomScope extends ConsumerStatefulWidget {
  const TextZoomScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TextZoomScope> createState() => _TextZoomScopeState();
}

class _TextZoomScopeState extends ConsumerState<TextZoomScope> {
  /// Counts the zoom gestures, so the toast shows after each.
  final _gestures = ValueNotifier(0);

  TextZoomController get _zoom => ref.read(textZoomProvider.notifier);

  @override
  void dispose() {
    _gestures.dispose();
    super.dispose();
  }

  void _zoomTo(TextZoom zoom) {
    unawaited(_zoom.set(zoom));
    _gestures.value++;
  }

  void _zoomBy(TextZoom Function(TextZoom zoom) next) {
    unawaited(_zoom.change(next));
    _gestures.value++;
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
          // The toast outside the zoom: the same size at any zoom.
          child: TextZoomToastHost(
            zoom: zoom,
            shows: _gestures,
            child: TextZoomScale(zoom: zoom, child: widget.child),
          ),
        ),
      ),
    );
  }
}
