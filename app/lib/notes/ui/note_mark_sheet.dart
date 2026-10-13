import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_colors.dart';

/// Lets the user pin [note] or pick its color, then saves the choice.
Future<void> editNoteMark(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final actions = ref.read(noteActionsProvider);
  final chosen = await showModalBottomSheet<NoteMark>(
    context: context,
    builder: (_) => _NoteMarkSheet(actions.markOf(note)),
  );
  if (chosen == null) return;
  final saved = await actions.setMark(note, chosen);
  if (saved case Err(:final error) when context.mounted) {
    showSnack(context, error.text);
  }
}

/// Pin toggle and color choice; closes with the new mark on any tap.
class _NoteMarkSheet extends StatelessWidget {
  const _NoteMarkSheet(this.mark);

  final NoteMark mark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void choose(NoteMark chosen) => Navigator.pop(context, chosen);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                mark.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
              title: Text(mark.pinned ? 'Unpin' : 'Pin'),
              onTap: () => choose(mark.withPinned(pinned: !mark.pinned)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _ColorChoice(
                    tooltip: 'No color',
                    color: scheme.surface,
                    selected: mark.color == null,
                    onTap: () => choose(mark.withColor(null)),
                  ),
                  for (final name in noteColors.keys)
                    _ColorChoice(
                      tooltip: name,
                      color: noteTint(name, scheme)!,
                      selected: mark.color == name,
                      onTap: () => choose(mark.withColor(name)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.tooltip,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: selected ? Icon(Icons.check, color: scheme.primary) : null,
        ),
      ),
    );
  }
}
