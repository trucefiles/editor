/// What the system lets alerts do on this device.
abstract interface class AlertPermissions {
  /// Whether alerts may show; `false` while the user denies notifications.
  Future<bool> mayNotify();

  /// Asks the user to let alerts show; whether they may now.
  Future<bool> askToNotify();

  /// Asks the user to let alarms show full screen over other apps and the
  /// lock screen, where the system asks for that.
  Future<void> askForFullScreen();
}

/// Where alerts need no permission.
final class GrantedAlertPermissions implements AlertPermissions {
  const GrantedAlertPermissions();

  @override
  Future<bool> mayNotify() async => true;

  @override
  Future<bool> askToNotify() async => true;

  @override
  Future<void> askForFullScreen() async {}
}
