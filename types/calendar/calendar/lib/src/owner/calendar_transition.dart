import 'package:truce_core/truce_core.dart'
    show
        EditorBook,
        EditorNotice,
        EditorSteps,
        EffectId,
        SentText,
        ShownStep,
        Step,
        StepRun,
        TextSummary;

import '../edit/calendar_edit.dart';
import '../edit/edit_landing.dart';
import '../model/calendar.dart';
import '../support/calendar_summary.dart';
import 'calendar_contract.dart';

/// The calendar editor owner's decision on [message] in [state], with its
/// [book]; undo steps are the calendar before and after each edit.
Step<
  CalendarState,
  EditorBook<CalendarStep>,
  CalendarOwnerEvent,
  CalendarSaveTimer
>
calendarStep(
  CalendarState state,
  EditorBook<CalendarStep> book,
  CalendarMessage message,
) {
  return _Step(state, book).run(message);
}

/// One message's handling: the state as it changes and what it leads to.
final class _Step
    extends
        StepRun<
          CalendarMessage,
          CalendarState,
          EditorBook<CalendarStep>,
          CalendarOwnerEvent,
          CalendarSaveTimer
        >
    with EditorSteps<CalendarStep> {
  _Step(super.state, super.work);

  @override
  EditorBook<CalendarStep> get book => work;

  @override
  set book(EditorBook<CalendarStep> book) => work = book;

  /// When the request handled now was made; set before it is handled.
  late DateTime _requestAt;

  @override
  void handle(CalendarMessage message) {
    switch (message) {
      case EditCalendar(:final edit, :final newUid):
        if (state.calendar case final calendar?) {
          final landed = landing(calendar, edit, newUid: newUid);
          final edited = applyEdit(calendar, landed.edit);
          if (edited.text != calendar.text) {
            final before = _shown;
            _showCalendar(edited);
            textChanged();
            record(ShownStep(before, _shown), null);
          }
          if (landed.gone case final gone?) events.add(SavedAsNew(gone));
        }
      case CalendarRequest(:final request, :final at):
        _requestAt = at;
        handleRequest(request);
      case CalendarTimerFired(:final id):
        fired(id);
    }
    _settleStatus();
  }

  @override
  void notify(EditorNotice notice) => events.add(CalendarNotice(notice));

  @override
  void startTimer(EffectId id, Duration delay) =>
      effects.add(CalendarSaveTimer(id, delay));

  @override
  void undo(CalendarStep step) => _restore(step.before);

  @override
  void redo(CalendarStep step) => _restore(step.after);

  /// [back] shows again: a calendar stamped as an edit made when it was
  /// asked; a text that is no calendar as it is.
  void _restore(CalendarShown back) =>
      switch ((back.calendar, state.calendar)) {
        (final back?, final now?) => _showCalendar(
          broughtBack(back, now, _requestAt),
        ),
        (final back?, null) => _showCalendar(back),
        (null, _) => reload(back.text),
      };

  @override
  void reload(String text) => _show(text, Calendar.read(text));

  /// A backup restored: stamped as an edit, as an undo is, so a merge with
  /// the text it replaced keeps it.
  @override
  CalendarStep replaceText(String text) {
    final before = _shown;
    _restore((text: text, calendar: Calendar.read(text)));
    return ShownStep(before, _shown);
  }

  @override
  SentText get sent => SentText(state.text, CalendarSummary(state.text));

  @override
  TextSummary<Object?> summaryOfShown(String text) => CalendarSummary(text);

  /// Only the page shows the calendar; nothing shows the text kept.
  @override
  bool get sendsAtOnce => false;

  /// What shows now.
  CalendarShown get _shown => (text: state.text, calendar: state.calendar);

  void _showCalendar(Calendar calendar) => _show(calendar.text, calendar);

  void _show(String text, Calendar? calendar) => state = CalendarState(
    text,
    calendar,
    revision: state.revision + 1,
    status: book.status,
  );

  void _settleStatus() {
    if (state.status == book.status) return;
    state = CalendarState(
      state.text,
      state.calendar,
      revision: state.revision,
      status: book.status,
    );
  }
}
