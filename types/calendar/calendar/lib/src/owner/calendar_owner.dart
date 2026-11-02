import 'package:truce_core/truce_core.dart'
    show EditorBook, Machine, MachineOwner, Owner, StartTimer, Version;

import '../model/calendar.dart';
import '../support/calendar_summary.dart';
import 'calendar_contract.dart';
import 'calendar_transition.dart';

export 'calendar_contract.dart';

/// The owner of the calendar one open calendar file's page shows (see
/// `calendar_contract.dart`).
typedef CalendarOwner = Owner<CalendarInput, CalendarState, CalendarNotice>;

/// The calendar editor owner's machine; its work is its edits'
/// bookkeeping, with the calendars undo comes back to.
typedef CalendarMachine =
    Machine<
      CalendarMessage,
      CalendarState,
      EditorBook<CalendarShown>,
      CalendarNotice,
      CalendarSaveTimer
    >;

/// The editor owner of a calendar file holding [text], read as
/// [version] (`null` for a new file); its only effects are the save
/// timers, which [startTimer] starts (a fake clock in tests).
CalendarOwner calendarOwner(
  String text, {
  required Version? version,
  StartTimer? startTimer,
}) =>
    MachineOwner<
      CalendarMessage,
      CalendarInput,
      CalendarTimerFired,
      CalendarState,
      EditorBook<CalendarShown>,
      CalendarNotice,
      CalendarSaveTimer
    >(calendarMachine(text, version: version), startTimer: startTimer);

/// The calendar editor machine of a file holding [text], read as
/// [version] (`null` for a new file).
CalendarMachine calendarMachine(String text, {required Version? version}) {
  final book = EditorBook<CalendarShown>(
    lineage: version,
    summary: CalendarSummary(text),
  );
  return Machine(
    state: CalendarState(
      text,
      Calendar.read(text),
      revision: 0,
      status: book.status,
    ),
    work: book,
    step: calendarStep,
  );
}
