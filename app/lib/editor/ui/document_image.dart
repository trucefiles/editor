import 'package:flutter/material.dart';

/// The image a document's image reference [url] leads to; `null` for one the
/// app does not show (e.g. outside the document's folder).
typedef DocumentImages = ImageProvider? Function(String url);

/// The image at [url] of a document, as [images] finds it, at most as wide as
/// the document and not too tall; its [alt] text where it can't show.
class DocumentImage extends StatelessWidget {
  const DocumentImage(
    this.url, {
    required this.alt,
    required this.images,
    super.key,
  });

  final String url;
  final String alt;
  final DocumentImages images;

  static const _maxHeight = 320.0;

  @override
  Widget build(BuildContext context) {
    final altText = Text(
      alt.isEmpty ? url : alt,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
    final image = images(url);
    if (image == null) return altText;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      child: Image(
        image: image,
        semanticLabel: alt,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => altText,
      ),
    );
  }
}
