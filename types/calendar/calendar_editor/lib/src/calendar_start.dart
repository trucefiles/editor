import 'package:flutter/foundation.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

/// What a calendar's page is asked to start with once its calendar
/// shows: adding, or editing one occurrence.
sealed class CalendarStart {
  const CalendarStart();
}

/// Start adding: an event, or for a health calendar an entry of a kind
/// picked first.
final class StartAdding extends CalendarStart {
  const StartAdding();
}

/// Edit the occurrence of event [uid] at [recurrence] (`null`: an event
/// that doesn't repeat) that starts at [start], on this device's clock.
final class EditOccurrence extends CalendarStart {
  const EditOccurrence(this.uid, this.recurrence, {required this.start});

  /// [occurrence]'s edit.
  EditOccurrence.of(Occurrence occurrence)
    : this(
        occurrence.event.uid,
        occurrence.recurrence,
        start: occurrence.start,
      );

  final String uid;
  final CalendarTime? recurrence;
  final DateTime start;
}

/// Starts asked of calendar pages by file, e.g. by the Calendar tab
/// before it opens the file: a page's view moves the one for its file
/// into the page's own [PageStarts] when it shows. One for the whole app.
final class CalendarStarts {
  final _asked = <FileKey, CalendarStart>{};

  /// Asks the page of [file] to start with [start] once it opens.
  void ask(FileKey file, CalendarStart start) => _asked[file] = start;

  /// The start asked for [file], now taken; `null` if none.
  CalendarStart? take(FileKey file) => _asked.remove(file);

  /// Drops what was asked for [file] and not taken (e.g. its page didn't
  /// open), so a later open doesn't start it.
  void forget(FileKey file) => _asked.remove(file);
}

/// The starts asked of one calendar's page: what the app asked before it
/// opened, and its Add button. The page takes each once its calendar can
/// be edited; a later one replaces one not yet taken.
final class PageStarts extends ChangeNotifier {
  CalendarStart? _asked;

  /// Asks the page to start with [start].
  void ask(CalendarStart start) {
    _asked = start;
    notifyListeners();
  }

  /// The start asked, now taken; `null` if none.
  CalendarStart? take() {
    final asked = _asked;
    _asked = null;
    return asked;
  }
}
