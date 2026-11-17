/// Starting the app in the tray when the user logs in, where the desktop
/// lets the app ask for it.
abstract interface class LoginStart {
  /// Asks the desktop to start the app in the tray at login, or no longer
  /// to; whether the desktop agreed.
  Future<bool> set({required bool start});
}
