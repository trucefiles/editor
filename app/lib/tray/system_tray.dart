import 'package:flutter/foundation.dart';

/// An icon in the desktop's system tray, with a menu to open or quit the
/// app.
abstract interface class SystemTray {
  /// Whether a tray shows the icon right now. Changes when the desktop's
  /// tray starts or stops.
  ValueListenable<bool> get visible;

  /// Puts the icon in the tray, now or once a tray starts.
  Future<void> show({
    required VoidCallback onOpen,
    required VoidCallback onQuit,
  });

  /// Takes the icon out of the tray.
  Future<void> hide();
}
