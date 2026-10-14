import 'package:flutter/foundation.dart';

/// Whether the desktop runs a tray that can show the app's icon.
abstract interface class TrayHost {
  /// Changes when the desktop's tray starts or stops.
  ValueListenable<bool> get present;

  /// Starts following [present].
  Future<void> watch();

  Future<void> stop();
}
