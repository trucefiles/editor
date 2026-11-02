import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/screen_shortcuts.dart';
import '../../settings/device_settings_controller.dart';
import '../text_zoom.dart';
import '../text_zoom_target.dart';
import 'document_text_zoom.dart';
import 'pinch_to_zoom.dart';
import 'text_zoom_keys.dart';
import 'text_zoom_scale.dart';
import 'text_zoom_title.dart';
import 'text_zoom_toast_host.dart';
import 'wheel_to_zoom.dart';

/// [child], the whole app, with its text at the app's zoom, and document text
/// ([DocumentTextZoom]) at the document text zoom. On every
/// screen, the zoom keys ([textZoomKeys]), Ctrl with the mouse wheel and
/// pinching change the document text zoom; each such change shows it for a
/// moment ([TextZoomToastHost]).
class TextZoomScope extends ConsumerStatefulWidget {
  const TextZoomScope({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<TextZoomScope> createState() => _TextZoomScopeState();
}

class _TextZoomScopeState extends ConsumerState<TextZoomScope> {
  /// The zoom gestures change.
  static const _gestured = TextZoomTarget.documents;

  /// Counts the zoom gestures, so the toast shows after each.
  final _gestures = ValueNotifier(0);

  @override
  void dispose() {
    _gestures.dispose();
    super.dispose();
  }

  void _zoomTo(TextZoom zoom) => _zoomBy((_) => zoom);

  /// Changes the zoom from the one the change before left.
  void _zoomBy(TextZoom Function(TextZoom zoom) next) {
    unawaited(
      ref
          .read(deviceSettingsProvider.notifier)
          .change(
            (settings) => settings.withTextZoom(
              _gestured,
              next(settings.textZoomOf(_gestured)),
            ),
          ),
    );
    _gestures.value++;
  }

  TextZoom _watch(TextZoomTarget target) => ref.watch(
    deviceSettingsProvider.select((s) => s.requireValue.textZoomOf(target)),
  );

  @override
  Widget build(BuildContext context) {
    final zoom = _watch(_gestured);
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
            title: textZoomTitle(_gestured),
            zoom: zoom,
            shows: _gestures,
            child: DocumentTextZoomScope(
              zoom: zoom,
              child: TextZoomScale(
                zoom: _watch(TextZoomTarget.app),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
