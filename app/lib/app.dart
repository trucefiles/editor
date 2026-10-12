import 'package:flutter/material.dart';

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
      home: const Scaffold(body: Center(child: Text(title))),
    );
  }
}
