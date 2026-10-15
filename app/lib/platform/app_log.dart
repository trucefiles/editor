import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Prints the log records of the app and its core to stdout (logcat on
/// Android), for whoever wants to see what happens under the hood.
void printLogs() {
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen(
    (record) => debugPrint(
      '${record.time.toIso8601String()} ${record.level.name} '
      '${record.loggerName}: ${record.message}',
    ),
  );
}
