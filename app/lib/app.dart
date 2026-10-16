import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'common/keypad_navigation.dart';
import 'common/mouse_back_navigation.dart';
import 'notes/ui/notes_screen.dart';
import 'reach/ui/reach_overlay.dart';
import 'theme/app_theme.dart';
import 'tray/close_to_tray_controller.dart';

/// Root widget: app-wide theme, the first screen, the tray, and the
/// overlay while a folder is being reached again.
class TruceApp extends ConsumerStatefulWidget {
  const TruceApp({super.key});

  static const title = 'Truce Editor';

  @override
  ConsumerState<TruceApp> createState() => _TruceAppState();
}

class _TruceAppState extends ConsumerState<TruceApp> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    // Keeps the tray icon for as long as the app runs.
    ref.listen(closeToTrayProvider, (_, _) {});
    return MaterialApp(
      title: TruceApp.title,
      navigatorKey: _navigator,
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      builder: (context, child) => ReachOverlay(
        child: MouseBackNavigation(
          navigator: _navigator,
          child: KeypadNavigation(child: child!),
        ),
      ),
      home: const NotesScreen(),
    );
  }
}
