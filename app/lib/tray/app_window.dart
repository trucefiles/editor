/// The app's main window, as the desktop shell sees it.
abstract interface class AppWindow {
  /// Whether closing the window only hides it, so the app keeps running.
  Future<void> setHideOnClose({required bool hide});

  /// Shows the window again, also when hidden, and brings it to the front.
  Future<void> show();

  /// Quits as closing the window would without [setHideOnClose]: edits are
  /// kept first, or the user is asked.
  Future<void> quit();
}
