import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';

import 'event_colors.dart';

/// The event form's color row: the calendar's color (no own color), then
/// the colors offered. An own color the form doesn't offer (e.g. from
/// another app) shows first, picked, and stays unless the user picks
/// another.
class ColorChoice extends StatelessWidget {
  const ColorChoice({required this.color, required this.onColor, super.key});

  /// The event's own color; `null` for its calendar's.
  final EventColor? color;
  final ValueChanged<EventColor?> onColor;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    final choices = [
      if (color != null && !eventColorChoices.contains(color)) color,
      ...eventColorChoices,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('Calendar color'),
          selected: color == null,
          onSelected: (_) => onColor(null),
        ),
        for (final choice in choices)
          _Swatch(
            choice,
            picked: choice == color,
            onTap: () => onColor(choice),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.color, {required this.picked, required this.onTap});

  final EventColor color;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rgb = color.rgb;
    final fill = rgb == null ? null : Color(0xFF000000 | rgb);
    return Semantics(
      label: color.value,
      selected: picked,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: picked
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.outlineVariant,
              width: picked ? 3 : 1,
            ),
          ),
          child: fill == null
              ? const Icon(Icons.question_mark, size: 16)
              : null,
        ),
      ),
    );
  }
}
