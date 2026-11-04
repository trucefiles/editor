import 'package:flutter/material.dart';

import '../file_colors.dart';

/// A circle per file color, and one for none; the [selected] one ticked.
/// Tells [onPicked] the color tapped (`null`: none).
class ColorCircles extends StatelessWidget {
  const ColorCircles({
    required this.selected,
    required this.onPicked,
    super.key,
  });

  final String? selected;
  final ValueChanged<String?> onPicked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _Circle(
          tooltip: 'No color',
          color: scheme.surface,
          selected: selected == null,
          onTap: () => onPicked(null),
        ),
        for (final name in fileColors.keys)
          _Circle(
            tooltip: name,
            color: fileTint(name, scheme)!,
            selected: selected == name,
            onTap: () => onPicked(name),
          ),
      ],
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({
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
