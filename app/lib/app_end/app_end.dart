import 'dart:async';

import 'app_end_source.dart';

/// Keeps every open file's edits as the app is ended from outside: the
/// desktop session ends, or the system asks the app to stop. (The user's
/// own quit is the open pages' question.) One keep at a time: ends that
/// come meanwhile join it, and the app quits once.
final class AppEnd {
  /// [keepAll] keeps the edits of every open file, at least on the
  /// device, and completes once their files hold them as far as they
  /// can now, waiting at most a set time; [quit] ends the app without
  /// asking.
  AppEnd({required this.keepAll, required this.quit});

  final Future<void> Function() keepAll;
  final Future<void> Function() quit;

  Future<void>? _keeping;
  Future<void>? _quitting;

  /// The app is ended from outside, as [kind] says: the edits are kept,
  /// and the app quits if it must.
  Future<void> ended(AppEndKind kind) async {
    await _keep();
    switch (kind) {
      case AppEndKind.sessionEnding:
        break;
      case AppEndKind.stopAsked:
        await (_quitting ??= quit());
    }
  }

  /// Keeps every open file's edits.
  Future<void> _keep() =>
      _keeping ??= keepAll().whenComplete(() => _keeping = null);
}
