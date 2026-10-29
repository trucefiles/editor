import 'package:flutter/foundation.dart';

import 'view_settings.dart';

/// What cards and search show of one version of a document: its title and
/// its preview, as the document's view settings on this device say. Worked
/// out by the document's type, from one read of the text; holds only the
/// strings shown, never the text.
@immutable
final class DocumentCardSummary {
  const DocumentCardSummary({required this.title, required this.preview});

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// The text's own title, else the file name without its extension.
  final String title;

  /// The preview as the document's view settings say.
  final String Function(ViewSettings view) preview;
}
