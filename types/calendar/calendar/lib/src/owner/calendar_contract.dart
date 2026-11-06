/// The calendar editor owner's contract: what reaches it, what it
/// decides, what it leads to. One per open calendar; it holds the
/// calendar the page shows, runs the user's edits on it, and handles what
/// every type's editor shares (core's editor contract): the page's
/// requests, undo, and sending the text to the file owner as the save
/// timing says.
library;

import 'dart:typed_data';

import 'package:truce_core/truce_core.dart'
    show EditorNotice, EditorRequest, EditorStatus, EffectId, Wait;

import '../edit/calendar_edit.dart';
import '../edit/calendar_import.dart';
import '../edit/edit_landing.dart';
import '../model/calendar.dart';
import '../support/calendar_summary.dart';

export 'calendar_step.dart';

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
/// calendar, or if it changes nothing. A change of an event or date that
/// is gone meanwhile lands as the new event [newUid] (see [landing]).
final class EditCalendar extends CalendarInput {
  const EditCalendar(this.edit, {required this.newUid});

  final CalendarEdit edit;
  final String newUid;
}

/// The user names the calendar [name] (none if empty), as typed so far:
/// typing on in a name joins one undo step. Dropped while the text is no
/// calendar, or if the name is the same.
final class RenameCalendar extends CalendarInput {
  const RenameCalendar(this.name);

  final String name;
}

/// The user imports the events of the calendar file [bytes] [at] (see
/// `importInto`): one undo step, and [ImportDone] tells what came of it.
/// Dropped while the text is no calendar.
final class ImportEvents extends CalendarInput {
  const ImportEvents(this.bytes, {required this.at});

  final Uint8List bytes;
  final DateTime at;
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

/// What the owner tells.
sealed class CalendarOwnerEvent {
  const CalendarOwnerEvent();
}

/// What the file page hears (see core's editor contract).
final class CalendarNotice extends CalendarOwnerEvent {
  const CalendarNotice(this.notice);

  final EditorNotice notice;
}

/// An edit of what was [gone] was saved as a new event, for the user to
/// hear why.
final class SavedAsNew extends CalendarOwnerEvent {
  const SavedAsNew(this.gone);

  final GoneMeanwhile gone;
}

/// An import of the user's is done, as [report] says.
final class ImportDone extends CalendarOwnerEvent {
  const ImportDone(this.report);

  final ImportReport report;
}

// State.

/// What the page shows: a [calendar], or a [text] that is none (it
/// shows, and takes no edits). A calendar's text is printed only when
/// asked, so an edit costs no print of the whole file.
final class CalendarState {
  /// [text], as read: [calendar], `null` if it is none.
  const CalendarState(
    String text,
    Calendar? calendar, {
    required int revision,
    required EditorStatus status,
  }) : this._(
         calendar,
         calendar == null ? text : null,
         revision: revision,
         status: status,
       );

  /// [calendar], its text printed only when asked.
  const CalendarState.of(
    Calendar calendar, {
    required int revision,
    required EditorStatus status,
  }) : this._(calendar, null, revision: revision, status: status);

  const CalendarState._(
    this.calendar,
    this._noCalendar, {
    required this.revision,
    required this.status,
  });

  /// The calendar shown; `null` if the text is none.
  final Calendar? calendar;

  /// The text, kept only when it is no calendar.
  final String? _noCalendar;

  /// Counts the changes to what shows.
  final int revision;

  /// What it tells of the edits: whether some are only in memory, and
  /// what undo and redo can do.
  final EditorStatus status;

  /// The text shown.
  String get text => calendar?.text ?? _noCalendar!;

  /// What lists show of [text], from the calendar as read.
  CalendarSummary get summary => switch (calendar) {
    final calendar? => CalendarSummary.of(calendar),
    null => CalendarSummary(text),
  };

  /// The same shown, telling [status].
  CalendarState withStatus(EditorStatus status) => CalendarState._(
    calendar,
    _noCalendar,
    revision: revision,
    status: status,
  );
}
