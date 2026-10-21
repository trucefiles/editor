import 'package:flutter/foundation.dart';
import 'package:truce_core/truce_core.dart';

import 'note_title.dart';

/// What cards and search show of one version of a note: its title and
/// its preview, with and without checked items. Worked out from one
/// parse of the text.
@immutable
final class NoteSummary {
  const NoteSummary({
    required this.title,
    required this.preview,
    required this.previewHidingDone,
  });

  /// The summary of [text], the content of the note at [path], with
  /// previews of up to [maxLines] lines.
  factory NoteSummary.of(
    String text,
    RelPath path, {
    int maxLines = previewLines,
  }) {
    final document = MarkdownDocument.parse(text);
    return NoteSummary(
      title: noteTitleIn(document, path),
      preview: notePreviewIn(document, maxLines: maxLines),
      previewHidingDone: notePreviewIn(
        document,
        maxLines: maxLines,
        hideDone: true,
      ),
    );
  }

  /// Most lines a preview holds.
  static const previewLines = 10;

  /// See [noteTitle].
  final String title;

  /// See [notePreviewIn].
  final String preview;

  /// [preview] with checked items left out and counted instead.
  final String previewHidingDone;

  /// [previewHidingDone] if [hideDone], else [preview].
  String previewOf({required bool hideDone}) =>
      hideDone ? previewHidingDone : preview;
}
