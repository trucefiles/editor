import 'package:flutter/services.dart';

/// The keypad's navigation keys and the main keys they stand for while
/// NumLock is off: every part that handles keys acts on them as on those.
final keypadStandsFor = {
  LogicalKeyboardKey.numpad4: LogicalKeyboardKey.arrowLeft,
  LogicalKeyboardKey.numpad6: LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.numpad8: LogicalKeyboardKey.arrowUp,
  LogicalKeyboardKey.numpad2: LogicalKeyboardKey.arrowDown,
  LogicalKeyboardKey.numpad7: LogicalKeyboardKey.home,
  LogicalKeyboardKey.numpad1: LogicalKeyboardKey.end,
  LogicalKeyboardKey.numpad9: LogicalKeyboardKey.pageUp,
  LogicalKeyboardKey.numpad3: LogicalKeyboardKey.pageDown,
};
