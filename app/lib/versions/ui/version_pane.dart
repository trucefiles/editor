import 'package:flutter/material.dart';

import '../../common/full_time.dart';
import '../changed_lines.dart';

/// One side of a conflict: its text with lines the other side lacks
/// highlighted, and a button to keep it.
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
            final time? => Text(
              fullTime(MaterialLocalizations.of(context), time),
            ),
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
            final text => _HighlightedText(text, compareTo),
          },
        ),
      ],
    );
  }
}

class _HighlightedText extends StatelessWidget {
  const _HighlightedText(this.text, this.compareTo);

  final String text;
  final String compareTo;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final changed = changedLines(lines, compareTo.split('\n'));
    final highlight = Theme.of(context).colorScheme.tertiaryContainer;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (var i = 0; i < lines.length; i++)
              TextSpan(
                text: i < lines.length - 1 ? '${lines[i]}\n' : lines[i],
                style: changed.contains(i)
                    ? TextStyle(backgroundColor: highlight)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}
