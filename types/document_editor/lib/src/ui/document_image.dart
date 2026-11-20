import 'package:flutter/material.dart';

import 'package:truce_common_ui/truce_common_ui.dart';

/// The images a document shows. Equal when they find the same images, so
/// a view builds what shows them again only when they change.
abstract interface class DocumentImageLookup {
  /// The image a document's image reference [url] leads to; `null` for
  /// one the app does not show (e.g. outside the document's folder).
  ImageProvider? of(String url);
}

/// A document that shows no images, e.g. one not in a folder.
final class NoDocumentImageLookup implements DocumentImageLookup {
  const NoDocumentImageLookup();

  @override
  ImageProvider? of(String url) => null;

  @override
  bool operator ==(Object other) => other is NoDocumentImageLookup;

  @override
  int get hashCode => (NoDocumentImageLookup).hashCode;
}

/// The image at [url] of a document, as [images] finds it, at most as
/// wide as the document and not too tall; its [alt] text where it can't
/// show. The one image widget of the document views: if [opens], a tap
/// shows it full screen (see [showImageViewer]); where the view's own
/// taps come first (Visual edit), the view opens it itself.
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
        image: image,
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
