import 'package:flutter/material.dart';

import 'common/keypad_navigation.dart';
import 'notes/ui/notes_screen.dart';

/// Root widget: app-wide theme and the first screen.
class TruceApp extends StatelessWidget {
  const TruceApp({super.key});

  static const title = 'Truce Editor';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      builder: (context, child) => KeypadNavigation(child: child!),
      home: const NotesScreen(),
    );
  }
}
