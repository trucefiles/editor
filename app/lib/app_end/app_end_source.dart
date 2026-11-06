/// How the app is ended from outside it.
enum AppEndKind {
  /// The desktop session is about to end. The user may still cancel it,
  /// so the app keeps running; if the session ends, it ends the app.
  sessionEnding,

  /// The system asks the app to stop: it must go.
  stopAsked,
}

/// Tells that the app is about to be ended from outside, as one platform
/// hears it.
abstract interface class AppEndSource {
  /// Calls [onEnd] each time the app is about to be ended; the platform
  /// holds the end, as far as it can, until its future completes. The
  /// returned call stops listening.
  void Function() listen(Future<void> Function(AppEndKind kind) onEnd);
}
