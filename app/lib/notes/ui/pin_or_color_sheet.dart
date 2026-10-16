import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:truce_core/truce_core.dart';

import '../../common/error_text.dart';
import '../../common/snack.dart';
import '../note.dart';
import '../note_actions.dart';
import '../note_colors.dart';
import '../note_settings_controller.dart';

/// Lets the user pin [note] (on this device) or pick its color (on every
/// device), then saves the choice.
Future<void> editPinOrColor(
  BuildContext context,
  WidgetRef ref,
  Note note,
) async {
  final actions = ref.read(noteActionsProvider);
  final settings = ref.read(noteSettingsProvider.notifier);
  final pinned = settings.settingsOf(note.key).pinned;
  final chosen = await showModalBottomSheet<_Choice>(
    context: context,
    builder: (_) =>
        _PinOrColorSheet(pinned: pinned, color: actions.markOf(note).color),
  );
  switch (chosen) {
    case null:
      return;
    case _Pin(:final pinned):
      await settings.edit(
        note.key,
        (current) => current.withPinned(pinned: pinned),
      );
    case _Color(:final color):
      final mark = actions.markOf(note).withColor(color);
      final saved = await actions.setMark(note, mark);
      if (saved case Err(:final error) when context.mounted) {
        showSnack(context, error.text);
      }
  }
}

sealed class _Choice {
  const _Choice();
}

final class _Pin extends _Choice {
  const _Pin({required this.pinned});

  final bool pinned;
}

final class _Color extends _Choice {
  const _Color(this.color);

  final String? color;
}

/// Pin toggle and color choice; closes with the choice on any tap.
class _PinOrColorSheet extends StatelessWidget {
  const _PinOrColorSheet({required this.pinned, required this.color});

  final bool pinned;
  final String? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    void choose(_Choice chosen) => Navigator.pop(context, chosen);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(pinned ? 'Unpin' : 'Pin'),
              onTap: () => choose(_Pin(pinned: !pinned)),
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
                    selected: color == null,
                    onTap: () => choose(const _Color(null)),
                  ),
                  for (final name in noteColors.keys)
                    _ColorChoice(
                      tooltip: name,
                      color: noteTint(name, scheme)!,
                      selected: color == name,
                      onTap: () => choose(_Color(name)),
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
