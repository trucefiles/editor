import 'dart:async';

import 'app_end_source.dart';

/// How long the app's end waits at most for the open files' edits to
/// reach their files: a folder that hangs never holds the app. What
/// isn't in its file by then waits on the device for the next start.
const appEndWait = Duration(seconds: 2);

/// Keeps every open file's edits as the app ends, whatever ends it: the
/// user quits, the desktop session ends, or the system asks the app to
/// stop. One keep at a time: ends that come meanwhile join it, and the
/// app quits once.
final class AppEnd {
  /// [keepAll] keeps the edits of every open file, at least on the
  /// device, and completes once their files hold them as far as they
  /// can now; [quit] ends the app without asking.
  AppEnd({required this.keepAll, required this.quit, this.wait = appEndWait});

  final Future<void> Function() keepAll;
  final Future<void> Function() quit;

  /// How long [keep] waits at most.
  final Duration wait;

  Future<void>? _keeping;
  Future<void>? _quitting;

  /// The app is ended from outside, as [kind] says: the edits are kept,
  /// and the app quits if it must.
  Future<void> ended(AppEndKind kind) async {
    await keep();
    switch (kind) {
      case AppEndKind.sessionEnding:
        break;
      case AppEndKind.stopAsked:
        await (_quitting ??= quit());
    }
  }

  /// Keeps every open file's edits, waiting at most [wait] for
  /// them to reach their files (e.g. before the user's quit goes on).
  Future<void> keep() => _keeping ??= _keptAll()
      .timeout(wait, onTimeout: () {})
      .whenComplete(() => _keeping = null);

  /// [keepAll] as a future of exactly `void`, which [Future.timeout]
  /// needs (e.g. a `Future.wait` is one of a list).
  Future<void> _keptAll() async => keepAll();
}
