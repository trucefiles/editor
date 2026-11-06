import 'package:flutter/services.dart';

import '../../app_end/app_end_source.dart';

/// The desktop session's end as GTK hears it from the session manager
/// (`linux/runner/session_end.cc`): the runner holds the end until the
/// app answers `queryEnd`.
final class GtkSessionEnd implements AppEndSource {
  const GtkSessionEnd();

  static const _channel = MethodChannel('io.github.trucefiles.editor/session');

  @override
  void Function() listen(Future<void> Function(AppEndKind kind) onEnd) {
    _channel.setMethodCallHandler(
      (call) => switch (call.method) {
        'queryEnd' => onEnd(AppEndKind.sessionEnding),
        _ => throw MissingPluginException(call.method),
      },
    );
    return () => _channel.setMethodCallHandler(null);
  }
}
