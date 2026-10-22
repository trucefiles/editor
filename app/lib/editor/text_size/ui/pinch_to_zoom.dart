import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../note_text_size.dart';
import '../note_text_size_controller.dart';

/// Pinching [child] with two fingers makes notes' text larger or smaller
/// as the fingers spread or close, step by step while they move. Every
/// touch still reaches [child] as well, so it scrolls and edits as before.
class PinchToZoom extends ConsumerStatefulWidget {
  const PinchToZoom({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends ConsumerState<PinchToZoom> {
  /// Where each finger on [PinchToZoom.child] is.
  final _fingers = <int, Offset>{};

  /// The pinch going on: the size and the fingers' distance it started
  /// at.
  ({NoteTextSize size, double span})? _pinch;

  double get _span {
    final [a, b] = _fingers.values.toList();
    return (a - b).distance;
  }

  void _down(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch) return;
    _fingers[event.pointer] = event.position;
    final size = ref.read(noteTextSizeProvider).value;
    _pinch = _fingers.length == 2 && size != null && _span > 0
        ? (size: size, span: _span)
        : null;
  }

  void _move(PointerMoveEvent event) {
    if (!_fingers.containsKey(event.pointer)) return;
    _fingers[event.pointer] = event.position;
    if (_pinch case (:final size, :final span)?) {
      unawaited(
        ref
            .read(noteTextSizeProvider.notifier)
            .set(NoteTextSize.closestTo(size.percent * _span / span)),
      );
    }
  }

  void _up(PointerEvent event) {
    _fingers.remove(event.pointer);
    _pinch = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: _up,
    child: widget.child,
  );
}
