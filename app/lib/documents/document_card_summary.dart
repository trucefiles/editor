import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart' show CheckedItems;

import 'document_settings.dart';
import 'document_title.dart';

/// What cards and search show of one version of a document: its title and
/// its preview, as the document's settings on this device say. Worked out
/// by the document's type, from one read of the text; holds only the
/// strings shown, never the text.
@immutable
final class DocumentCardSummary {
  const DocumentCardSummary({required this.title, required this.previews});

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// The text's own title, else the file name without its extension.
  final String title;

  /// The preview for each way checked items show: the only setting that
  /// shapes it.
  final Map<CheckedItems, String> previews;

  /// The preview as the document's [settings] say.
  String preview(DocumentSettings settings) => previews[settings.checkedItems]!;
}

/// [summary] as cards show it, of the document at [path]; [options] says
/// how the preview shows for each way checked items show.
DocumentCardSummary cardSummaryOf<O>(
  TextSummary<O> summary,
  RelPath path, {
  required O Function(CheckedItems checkedItems) options,
}) => DocumentCardSummary(
  title: titleOf(summary, path),
  previews: {
    for (final checkedItems in CheckedItems.values)
      checkedItems: summary.preview(options(checkedItems)),
  },
);
