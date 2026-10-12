import 'package:flutter/material.dart';

/// Colors offered for folders; distinct in light and dark themes.
const folderColors = <Color>[
  Colors.teal,
  Colors.indigo,
  Colors.orange,
  Colors.pink,
  Colors.green,
  Colors.purple,
  Colors.brown,
  Colors.blueGrey,
];

/// The first color not used by [used], so new folders differ by default.
Color nextFolderColor(Iterable<Color> used) {
  final taken = used.map((color) => color.toARGB32()).toSet();
  return folderColors.firstWhere(
    (color) => !taken.contains(color.toARGB32()),
    orElse: () => folderColors[taken.length % folderColors.length],
  );
}
