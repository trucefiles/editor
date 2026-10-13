import 'package:flutter/material.dart';

import 'common/keypad_navigation.dart';
import 'common/mouse_back_navigation.dart';
import 'notes/ui/notes_screen.dart';

/// Root widget: app-wide theme and the first screen.
class TruceApp extends StatefulWidget {
  const TruceApp({super.key});

  static const title = 'Truce Editor';

  @override
  State<TruceApp> createState() => _TruceAppState();
}

class _TruceAppState extends State<TruceApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: TruceApp.title,
      navigatorKey: _navigator,
      theme: ThemeData(colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      builder: (context, child) => MouseBackNavigation(
        navigator: _navigator,
        child: KeypadNavigation(child: child!),
      ),
      home: const NotesScreen(),
    );
  }
}
