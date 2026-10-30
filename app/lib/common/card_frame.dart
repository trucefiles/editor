import 'dart:math';

import 'package:flutter/material.dart';

import '../text_zoom/ui/document_text_zoom.dart';

/// The frame every card in a document grid shares: the title and [body] at
/// the document text zoom, [footer] at the bottom. It fills the height it
/// gets; in a grid that is [cardHeight].
class CardFrame extends StatelessWidget {
  const CardFrame({
    required this.title,
    required this.footer,
    required this.onTap,
    this.body,
    this.onMark,
    this.color,
    this.shape,
    super.key,
  });

  final String title;

  /// Document text under the title, usually a [CardLines].
  final Widget? body;

  final Widget footer;
  final VoidCallback onTap;

  /// Asks for a pin or color: on long press, or right click with a mouse.
  final VoidCallback? onMark;

  final Color? color;
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(_margin),
    clipBehavior: Clip.antiAlias,
    color: color,
    shape: shape,
    child: InkWell(
      onTap: onTap,
      onLongPress: onMark,
      onSecondaryTap: onMark,
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DocumentTextZoom(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: _titleGap,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (body case final body?) Expanded(child: body),
                  ],
                ),
              ),
            ),
            const SizedBox(height: _footerGap),
            SizedBox(height: _footerHeight(context), child: footer),
          ],
        ),
      ),
    ),
  );
}

/// [text] in the cards' body style, in as many whole lines as fit the
/// height it gets, the last one ending in "…" if more is left.
class CardLines extends StatelessWidget {
  const CardLines(this.text, {this.italic = false, super.key});

  final String text;
  final bool italic;

  @override
  Widget build(BuildContext context) {
    final style = _bodyStyle(context)
        ?.copyWith(fontStyle: italic ? FontStyle.italic : null);
    final line = _lineHeight(style, MediaQuery.textScalerOf(context));
    return LayoutBuilder(
      builder: (_, constraints) {
        final lines = (constraints.maxHeight / line).floor();
        return lines < 1
            ? const SizedBox.shrink()
            : Text(
                text,
                style: style,
                maxLines: lines,
                overflow: TextOverflow.ellipsis,
              );
      },
    );
  }
}

/// How tall each card in a document grid is: room for a one-line title,
/// [cardBodyLines] lines of preview and the footer, at the text zooms
/// in effect here.
double cardHeight(BuildContext context) {
  final text = Theme.of(context).textTheme;
  final document = DocumentTextZoom.scalerOf(context);
  return 2 * (_margin + _padding) +
      _lineHeight(text.titleMedium, document) +
      _titleGap +
      cardBodyLines * _lineHeight(_bodyStyle(context), document) +
      _footerGap +
      _footerHeight(context);
}

/// Lines of preview a card has room for under a one-line title.
const cardBodyLines = 6;

/// Size of an icon in a card's footer.
const cardFooterIconSize = 18.0;

TextStyle? _bodyStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodySmall;

const _margin = 4.0;
const _padding = 12.0;
const _titleGap = 6.0;
const _footerGap = 8.0;

/// Fits a line of small labels, a label with a background or an icon.
double _footerHeight(BuildContext context) => max(
  cardFooterIconSize,
  _lineHeight(
        Theme.of(context).textTheme.labelSmall,
        MediaQuery.textScalerOf(context),
      ) +
      4,
);

double _lineHeight(TextStyle? style, TextScaler scaler) {
  final painter = TextPainter(
    text: TextSpan(text: ' ', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}
