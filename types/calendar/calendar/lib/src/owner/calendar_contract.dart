/// The calendar editor owner's contract: what reaches it, what it
/// decides, what it leads to. One per open calendar; it holds the
/// calendar the page shows, runs the user's edits on it, and handles what
/// every type's editor shares (core's editor contract): the page's
/// requests, undo, and sending the text to the file owner as the save
/// timing says.
library;

import 'package:truce_core/truce_core.dart'
    show EditorNotice, EditorRequest, EditorStatus, EffectId, Wait;

import '../edit/calendar_edit.dart';
import '../model/calendar.dart';

/// What the editor shows at one undo step: the [text], and the
/// [calendar] read from it (`null` if it is no calendar).
typedef CalendarShown = ({String text, Calendar? calendar});

/// What the calendar editor owner handles: inputs anyone may send, and
/// the results of its effects.
sealed class CalendarMessage {
  const CalendarMessage();
}

// Inputs.

sealed class CalendarInput extends CalendarMessage {
  const CalendarInput();
}

/// The user's [edit]: one undo step. Dropped while the text is no
/// calendar, or if it changes nothing.
final class EditCalendar extends CalendarInput {
  const EditCalendar(this.edit);

  final CalendarEdit edit;
}

/// A request of the file page (see core's editor contract), made
/// [at]: what an undo or redo brings back is stamped as an edit then.
final class CalendarRequest extends CalendarInput {
  const CalendarRequest(this.request, {required this.at});

  final EditorRequest request;
  final DateTime at;
}

// Results.

/// The save timer [CalendarSaveTimer] started with [id] fired.
final class CalendarTimerFired extends CalendarMessage {
  const CalendarTimerFired(this.id);

  final EffectId id;
}

// Effects.

/// Fire [CalendarTimerFired] with [id] after [delay]: the one effect.
final class CalendarSaveTimer implements Wait<CalendarTimerFired> {
  const CalendarSaveTimer(this.id, this.delay);

  @override
  final EffectId id;
  @override
  final Duration delay;

  @override
  CalendarTimerFired get done => CalendarTimerFired(id);
}

// Events.

/// What the file page hears (see core's editor contract): the one
/// kind of event.
final class CalendarNotice {
  const CalendarNotice(this.notice);

  final EditorNotice notice;
}

// State.

/// What the page shows: the calendar's [text], read as [calendar] (`null`
/// if it is none: it shows, and takes no edits).
final class CalendarState {
  const CalendarState(
    this.text,
    this.calendar, {
    required this.revision,
    required this.status,
  });

  final String text;
  final Calendar? calendar;

  /// Counts the changes to what shows.
  final int revision;

  /// What it tells of the edits: whether some are only in memory, and
  /// what undo and redo can do.
  final EditorStatus status;
}
