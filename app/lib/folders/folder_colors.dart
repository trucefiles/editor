import 'package:flutter/material.dart';

/// Colors offered for folders, by the name the folder list keeps; distinct
/// in light and dark themes. Names must never change, or folders lose
/// their color.
const folderColors = <String, Color>{
  'teal': Colors.teal,
  'indigo': Colors.indigo,
  'orange': Colors.orange,
  'pink': Colors.pink,
  'green': Colors.green,
  'purple': Colors.purple,
  'brown': Colors.brown,
  'blueGrey': Colors.blueGrey,
};

/// The color of a folder colored [name]; the first offered for an unknown
/// name.
Color folderColor(String name) =>
    folderColors[name] ?? folderColors.values.first;
