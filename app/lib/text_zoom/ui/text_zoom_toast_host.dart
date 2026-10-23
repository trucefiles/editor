import 'dart:async';

import 'package:flutter/widgets.dart';

import '../text_zoom.dart';
import 'text_zoom_toast.dart';

/// [child] with a [TextZoomToast] of [title] at [zoom] over it, at the
/// bottom, for [time] after each time [shows] notifies.
class TextZoomToastHost extends StatefulWidget {
  const TextZoomToastHost({
    required this.title,
    required this.zoom,
    required this.shows,
    required this.child,
    this.time = const Duration(seconds: 2),
    super.key,
  });

  final String title;
  final TextZoom zoom;
  final Listenable shows;
  final Duration time;
  final Widget child;

  @override
  State<TextZoomToastHost> createState() => _TextZoomToastHostState();
}

class _TextZoomToastHostState extends State<TextZoomToastHost> {
  bool _shown = false;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.shows.addListener(_show);
  }

  @override
  void didUpdateWidget(TextZoomToastHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shows == widget.shows) return;
    oldWidget.shows.removeListener(_show);
    widget.shows.addListener(_show);
  }

  @override
  void dispose() {
    widget.shows.removeListener(_show);
    _hide?.cancel();
    super.dispose();
  }

  void _show() {
    _hide?.cancel();
    _hide = Timer(widget.time, () {
      if (mounted) setState(() => _shown = false);
    });
    if (!_shown) setState(() => _shown = true);
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_shown)
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 72),
              child: TextZoomToast(title: widget.title, zoom: widget.zoom),
            ),
          ),
        ),
    ],
  );
}
