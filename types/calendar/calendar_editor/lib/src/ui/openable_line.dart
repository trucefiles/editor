import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'event_links.dart';
import 'link_parts.dart';
import 'marked_line.dart';

/// A marked line of [text] whose links open with [links]; a place
/// ([isPlace]) without links opens whole, in a maps app. Plain text
/// without [links].
class OpenableLine extends StatefulWidget {
  const OpenableLine({
    required this.mark,
    required this.text,
    required this.style,
    required this.links,
    this.isPlace = false,
    super.key,
  });

  final Widget mark;
  final String text;
  final TextStyle? style;
  final EventLinks? links;
  final bool isPlace;

  @override
  State<OpenableLine> createState() => _OpenableLineState();
}

class _OpenableLineState extends State<OpenableLine> {
  /// The taps of the spans last built, ended on the next build.
  var _taps = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _endTaps();
    super.dispose();
  }

  void _endTaps() {
    for (final tap in _taps) {
      tap.dispose();
    }
    _taps = [];
  }

  @override
  Widget build(BuildContext context) {
    _endTaps();
    final links = widget.links;
    final text = widget.text;
    if (links == null) {
      return MarkedLine(mark: widget.mark, text: text, style: widget.style);
    }
    final parts = linkParts(text);
    final linkStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );
    TextSpan opening(String shown, VoidCallback open) {
      final tap = TapGestureRecognizer()..onTap = open;
      _taps.add(tap);
      return TextSpan(
        text: shown,
        style: linkStyle,
        mouseCursor: SystemMouseCursors.click,
        recognizer: tap,
      );
    }

    return MarkedLine.rich(
      mark: widget.mark,
      style: widget.style,
      text: TextSpan(
        children: widget.isPlace && parts.every((part) => part.link == null)
            ? [opening(text, () => unawaited(links.openPlace(text)))]
            : [
                for (final part in parts)
                  switch (part.link) {
                    final link? => opening(
                      part.text,
                      () => unawaited(links.openLink(link)),
                    ),
                    null => TextSpan(text: part.text),
                  },
              ],
      ),
    );
  }
}
