import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateUtils, TimeOfDay;
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_files/truce_files.dart';

/// What a calendar's page is asked to start with once its calendar
/// shows: adding, or editing one occurrence or task.
sealed class CalendarStart {
  const CalendarStart();
}

/// Start adding: an event, or for a health calendar an entry of a kind
/// picked first.
final class StartAdding extends CalendarStart {
  const StartAdding();
}

/// Edit the occurrence of event [uid] at its date [recurrence] (`null`:
/// an event that doesn't repeat) that starts at [start], both on this
/// device's clock.
final class EditOccurrence extends CalendarStart {
  const EditOccurrence(this.uid, this.recurrence, {required this.start});

  /// [occurrence]'s edit.
  EditOccurrence.of(EventOccurrence occurrence)
    : this(
        occurrence.item.uid,
        occurrence.recurrence?.local,
        start: occurrence.start,
      );

  final String uid;
  final DateTime? recurrence;
  final DateTime start;
}

/// Edit the task [uid], or its date [date] (`null`: a task that doesn't
/// repeat) due at [due] (`null`: never), both on this device's clock.
final class EditTask extends CalendarStart {
  const EditTask(this.uid, this.date, {required this.due});

  /// [entry]'s edit.
  EditTask.of(TaskEntry entry)
    : this(entry.task.uid, entry.date?.local, due: entry.due);

  final String uid;
  final DateTime? date;
  final DateTime? due;
}

/// Where a calendar's page shows first, this time only: the view [kind]
/// (`null`: its own) on [day] (`null`: today), in the week and day views
/// from [time] (`null`: the morning). The page's own remembered view
/// stays as it is.
final class ShowAt {
  const ShowAt(this.kind, {this.day, this.time});

  /// An [item] that starts, or is due, at [start], in the view [kind]
  /// where its tile starts: its day, and its time unless it lasts all
  /// day; a timed task [taskLength] before it is due. Without [start],
  /// on today.
  ShowAt.item(
    CalendarViewKind? kind,
    ItemKind item,
    DateTime? start, {
    required bool allDay,
  }) : this._at(
         kind,
         item == ItemKind.task && !allDay ? start?.subtract(taskLength) : start,
         allDay: allDay,
       );

  /// [occurrence] in the view [kind].
  ShowAt.occurrence(CalendarViewKind kind, EventOccurrence occurrence)
    : this.item(
        kind,
        ItemKind.event,
        occurrence.start,
        allDay: occurrence.allDay,
      );

  /// [entry] in the view [kind].
  ShowAt.task(CalendarViewKind kind, TaskEntry entry)
    : this.item(kind, ItemKind.task, entry.due, allDay: entry.allDay);

  ShowAt._at(this.kind, DateTime? at, {required bool allDay})
    : day = at == null ? null : DateUtils.dateOnly(at),
      time = at == null || allDay ? null : TimeOfDay.fromDateTime(at);

  final CalendarViewKind? kind;
  final DateTime? day;
  final TimeOfDay? time;
}

/// What a calendar's page is asked when it opens: where it shows first
/// ([showAt]; `null`: in its own view on today), and what it starts
/// with ([start]; `null`: nothing).
typedef PageOpening = ({ShowAt? showAt, CalendarStart? start});

/// What calendar pages are asked when they open, by file, e.g. by the
/// Calendar tab before it opens the file: a page's view moves the one
/// for its file into the page's own [PageStarts] when it shows. One for
/// the whole app.
final class CalendarStarts {
  final _asked = <FileKey, PageOpening>{};

  /// Asks the page of [file] to start with [start] once it opens, and to
  /// show [showAt] first.
  void ask(FileKey file, CalendarStart? start, {ShowAt? showAt}) =>
      _asked[file] = (showAt: showAt, start: start);

  /// What was asked for [file], now taken; `null` if nothing.
  PageOpening? take(FileKey file) => _asked.remove(file);

  /// Drops what was asked for [file] and not taken (e.g. its page didn't
  /// open), so a later open doesn't start it.
  void forget(FileKey file) => _asked.remove(file);
}

/// The starts asked of one calendar's page: what the app asked before it
/// opened, and its Add button. The page takes each once its calendar can
/// be edited; a later one replaces one not yet taken. Also where the
/// page shows first, taken once its views first show.
final class PageStarts extends ChangeNotifier {
  CalendarStart? _asked;
  ShowAt? _showAt;

  /// Asks the page to show [showAt] first.
  void showFirst(ShowAt showAt) => _showAt = showAt;

  /// Where the page shows first, now taken; `null` if not asked.
  ShowAt? takeShowAt() {
    final showAt = _showAt;
    _showAt = null;
    return showAt;
  }

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
