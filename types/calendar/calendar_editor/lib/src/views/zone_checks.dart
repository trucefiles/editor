import 'dart:async';

import 'package:flutter/widgets.dart';

/// Calls [check] every minute and whenever the app returns to the front:
/// neither Flutter nor the system tells the app of a time zone change, so
/// the views look for one then.
final class ZoneChecks {
  ZoneChecks(VoidCallback check)
    : _timer = Timer.periodic(const Duration(minutes: 1), (_) => check()),
      _lifecycle = AppLifecycleListener(onResume: check);

  final Timer _timer;
  final AppLifecycleListener _lifecycle;

  void dispose() {
    _timer.cancel();
    _lifecycle.dispose();
  }
}
