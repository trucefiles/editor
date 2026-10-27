import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_markdown/truce_markdown.dart';

import 'document_title.dart';

/// What cards and search show of one version of a document: its title and
/// its preview, with and without checked items. Worked out from one
/// read of the text.
@immutable
final class DocumentCardSummary {
  const DocumentCardSummary({
    required this.title,
    required this.preview,
    required this.previewHidingDone,
  });

  /// The summary of [text], the content of the document at [path], with
  /// previews of up to [maxLines] lines.
  factory DocumentCardSummary.of(
    String text,
    RelPath path, {
    int maxLines = previewLines,
  }) {
    final summary = DocumentSummary.of(text, maxLines: maxLines);
    return DocumentCardSummary(
      title: documentTitleOf(summary, path),
      preview: summary.preview,
      previewHidingDone: summary.previewHidingDone,
    );
  }

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// See [documentTitle].
  final String title;

  /// See [DocumentSummary.preview].
  final String preview;

  /// [preview] with checked items left out and counted instead.
  final String previewHidingDone;

  /// [previewHidingDone] if [hideDone], else [preview].
  String previewOf({required bool hideDone}) =>
      hideDone ? previewHidingDone : preview;
}
