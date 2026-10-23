import 'package:flutter/material.dart';

import '../../common/time_texts.dart';
import '../../text_zoom/ui/note_text_zoom.dart';
import '../compared_lines.dart';
import 'diff_colors.dart';

/// One side of a conflict: its text, at the note text zoom, compared
/// with the other side's as a line diff (lines only this side has as
/// added, lines only the other side has as removed), and a button to
/// keep it.
class VersionPane extends StatelessWidget {
  const VersionPane({
    required this.label,
    required this.modified,
    required this.text,
    required this.compareTo,
    required this.keepLabel,
    required this.onKeep,
    super.key,
  });

  final String label;
  final DateTime? modified;

  /// `null` if this version is a deleted file.
  final String? text;

  final String compareTo;
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
          subtitle: switch (modified) {
            final time? => Text(TimeTexts.of(context).full(time)),
            null => null,
          },
          trailing: FilledButton(onPressed: onKeep, child: Text(keepLabel)),
        ),
        Expanded(
          child: switch (text) {
            null => Center(
              child: Text(
                'Deleted on a device',
                style: theme.textTheme.bodyLarge,
              ),
            ),
            final text => NoteTextZoom(
              child: _HighlightedText(text, compareTo),
            ),
          },
        ),
      ],
    );
  }
}

/// [text] compared with [compareTo], one line per row; changed rows
/// are tinted across the whole width, as git hosts show a diff. Text
/// selects across rows.
class _HighlightedText extends StatelessWidget {
  const _HighlightedText(this.text, this.compareTo);

  final String text;
  final String compareTo;

  @override
  Widget build(BuildContext context) {
    final colors = DiffColors.of(Theme.of(context).brightness);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final line in compareLines(
              text.split('\n'),
              compareTo.split('\n'),
            ))
              ColoredBox(
                color: switch (line.origin) {
                  LineOrigin.both => Colors.transparent,
                  LineOrigin.shownOnly => colors.added,
                  LineOrigin.otherOnly => colors.removed,
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(line.text),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
