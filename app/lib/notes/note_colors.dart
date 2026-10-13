import 'package:flutter/material.dart';

/// Colors offered for notes, by the name saved in the synced marks. Names
/// must never change, or notes lose their color.
const noteColors = <String, Color>{
  'red': Colors.red,
  'orange': Colors.orange,
  'yellow': Colors.amber,
  'green': Colors.green,
  'teal': Colors.teal,
  'blue': Colors.blue,
  'purple': Colors.purple,
  'pink': Colors.pink,
};

/// Background of a note colored [name], light enough for text in either
/// theme; `null` for no or an unknown color.
Color? noteTint(String? name, ColorScheme scheme) => switch (noteColors[name]) {
  final color? => Color.alphaBlend(
    color.withValues(alpha: 0.25),
    scheme.surface,
  ),
  null => null,
};
