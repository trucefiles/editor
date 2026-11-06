import 'dart:typed_data';

import 'package:truce_calendar/truce_calendar.dart' show ImportReport;
import 'package:truce_core/truce_core.dart' show Result;

/// Asks the user for a calendar file to import and reads it whole: its
/// bytes; `null` if they picked none; [FileNotRead] if it can't be read.
typedef PickCalendarFile = Future<Result<Uint8List?, FileNotRead>> Function();

/// What an import the user asked for came to.
sealed class ImportOutcome {
  const ImportOutcome();
}

/// The picked file couldn't be read.
final class FileNotRead extends ImportOutcome {
  const FileNotRead();
}

/// The picked file was read and imported, as [report] says.
final class FileImported extends ImportOutcome {
  const FileImported(this.report);

  final ImportReport report;
}
