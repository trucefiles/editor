import 'package:logging/logging.dart';

final _log = Logger('alerts');

/// Does [act], ringing or showing one alert; whether it went through.
/// Where the platform fails it (no notification service, a refused call),
/// that alert is skipped and why is logged, so the alerts after it still
/// ring and the planner goes on.
Future<bool> orSkip(String what, Future<void> Function() act) async {
  try {
    await act();
    return true;
  } on Exception catch (error) {
    _log.warning("Couldn't $what: $error");
    return false;
  }
}
