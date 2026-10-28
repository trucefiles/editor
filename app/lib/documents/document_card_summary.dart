import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import 'document_file_name.dart';
import 'document_settings.dart';

/// What cards and search show of one version of a document: its title and
/// its preview, as the document's settings on this device say. Worked out
/// by the document's type, from one read of the text.
@immutable
final class DocumentCardSummary {
  const DocumentCardSummary({required this.title, required this.preview});

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// The text's own title, else the file name without its extension.
  final String title;

  /// The preview as the document's settings say.
  final String Function(DocumentSettings settings) preview;
}

/// [summary] as cards show it, of the document at [path]; [options] says
/// how the preview shows for the document's settings.
DocumentCardSummary cardSummaryOf<O>(
  TextSummary<O> summary,
  RelPath path, {
  required O Function(DocumentSettings settings) options,
}) => DocumentCardSummary(
  title: summary.title ?? splitFileName(path.name).base,
  preview: (settings) => summary.preview(options(settings)),
);
