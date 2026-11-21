import 'package:flutter/material.dart';

import 'package:truce_common_ui/truce_common_ui.dart';

/// The images a document shows. Equal when they find the same images, so
/// a view builds what shows them again only when they change.
abstract interface class DocumentImageLookup {
  /// The image a document's image reference [url] leads to, at the size
  /// it is asked at; `null` for one the app does not show (e.g. outside
  /// the document's folder).
  SizedImage? of(String url);
}

/// A document that shows no images, e.g. one not in a folder.
final class NoDocumentImageLookup implements DocumentImageLookup {
  const NoDocumentImageLookup();

  @override
  SizedImage? of(String url) => null;

  @override
  bool operator ==(Object other) => other is NoDocumentImageLookup;

  @override
  int get hashCode => (NoDocumentImageLookup).hashCode;
}

/// The image at [url] of a document, as [images] finds it, at most as
/// wide as the document and not too tall, and decoded no larger than
/// that; its [alt] text where it can't show. The one image widget of the
/// document views: if [opens], a tap shows it full screen (see
/// [showImageViewer]); where the view's own taps come first (Visual
/// edit), the view opens it itself.
class DocumentImage extends StatelessWidget {
  const DocumentImage(
    this.url, {
    required this.alt,
    required this.images,
    this.opens = false,
    super.key,
  });

  final String url;
  final String alt;
  final DocumentImageLookup images;
  final bool opens;

  static const _maxHeight = 320.0;

  /// The most it shows at on the screen of [context], in pixels:
  /// [_maxHeight] high, and as wide as any picture decodes (only a very
  /// wide one is as wide as the document), so it doesn't change with the
  /// window.
  static Within _shownSize(BuildContext context) => Within(
    DecodeSize.largestSide,
    (_maxHeight * MediaQuery.devicePixelRatioOf(context)).ceil(),
  );

  @override
  Widget build(BuildContext context) {
    final altText = Text(
      alt.isEmpty ? url : alt,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final image = images.of(url);
    if (image == null) return altText;
    final shown = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      child: Image(
        image: image(_shownSize(context)),
        semanticLabel: alt,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => altText,
      ),
    );
    if (!opens) return shown;
    return MouseRegion(
      cursor: SystemMouseCursors.zoomIn,
      child: GestureDetector(
        onTap: () => showImageViewer(context, image, alt: alt),
        child: shown,
      ),
    );
  }
}
