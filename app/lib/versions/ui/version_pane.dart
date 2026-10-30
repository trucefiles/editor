import 'package:flutter/material.dart';
import 'package:truce_documents/truce_documents.dart';

import '../../common/time_texts.dart';
import '../../text_zoom/ui/document_text_zoom.dart';
import 'diff_colors.dart';
import 'selectable_lines.dart';
import 'version_content.dart';

/// How a side of a diff marks the lines only it has.
enum OwnLines {
  /// As added: the side the diff is read against.
  added,

  /// As removed: the side compared with it.
  removed,
}

/// One side of a conflict: its own text, at the document text zoom, with
/// the lines the other side lacks marked as [ownLines], and a button to
/// keep it.
class VersionPane extends StatelessWidget {
  const VersionPane({
    required this.label,
    required this.content,
    required this.compareTo,
    required this.ownLines,
    required this.keepLabel,
    required this.onKeep,
    super.key,
  });

  final String label;
  final VersionContent content;

  /// The other side's text; `null` where it has none (a deleted file), so
  /// every line is this side's own.
  final String? compareTo;
  final OwnLines ownLines;
  final String keepLabel;

  /// `null` while disabled.
  final VoidCallback? onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          title: Text(label),
          // Every side has this line, so both texts start at one height.
          subtitle: Text(switch (content) {
            SavedText(:final modified) => TimeTexts.of(context).full(modified),
            EditorText() => 'In the editor now',
            DeletedFile() => 'Deleted',
          }),
          trailing: FilledButton(onPressed: onKeep, child: Text(keepLabel)),
        ),
        Expanded(
          child: switch (content.text) {
            null => Center(
              child: Text(
                'Deleted on a device',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            final text => DocumentTextZoom(
              child: _HighlightedText(text, compareTo, ownLines),
            ),
          },
        ),
      ],
    );
  }
}

/// [text] one line per row; the lines [compareTo] lacks are tinted as
/// [ownLines] across the whole width, as git hosts show a diff.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText(this.text, this.compareTo, this.ownLines);

  final String text;
  final String? compareTo;
  final OwnLines ownLines;

  @override
  Widget build(BuildContext context) {
    final colors = DiffColors.of(Theme.of(context).brightness);
    final tint = switch (ownLines) {
      OwnLines.added => colors.added,
      OwnLines.removed => colors.removed,
    };
    final lines = compareLines(
      text.split('\n'),
      compareTo?.split('\n') ?? const [],
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SelectionArea(
        child: SelectableLines(
          lines: [for (final line in lines) line.text],
          row: (index, text) => ColoredBox(
            color: lines[index].onlyHere ? tint : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}
