import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the app is in use: in the foreground, or a window still shown
/// without the focus. Not while hidden, in the background or closing.
final appActiveProvider = NotifierProvider<AppActivity, bool>(AppActivity.new);

class AppActivity extends Notifier<bool> {
  @override
  bool build() {
    final listener = AppLifecycleListener(
      onStateChange: (lifecycle) => state = _isActive(lifecycle),
    );
    ref.onDispose(listener.dispose);
    return _isActive(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  static bool _isActive(AppLifecycleState lifecycle) => switch (lifecycle) {
    AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => false,
  };
}
