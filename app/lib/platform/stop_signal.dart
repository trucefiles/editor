import 'dart:async';
import 'dart:io';

import '../app_end/app_end_source.dart';

/// The system asks the app to stop with SIGTERM (e.g. at shutdown, or
/// `systemctl poweroff`). Once watched, the signal no longer kills the
/// app: the app quits itself.
final class StopSignal implements AppEndSource {
  const StopSignal();

  @override
  void Function() listen(Future<void> Function(AppEndKind kind) onEnd) {
    final watching = ProcessSignal.sigterm.watch().listen(
      (_) => unawaited(onEnd(AppEndKind.stopAsked)),
    );
    return () => unawaited(watching.cancel());
  }
}
