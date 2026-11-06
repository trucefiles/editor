import 'package:truce_core/truce_core.dart'
    show
        EditorBook,
        EditorNotice,
        EditorSteps,
        EffectId,
        SentText,
        Step,
        StepRun,
        TextSummary,
        typingIn;

import '../edit/brought_back.dart';
import '../edit/calendar_edit.dart';
import '../edit/edit_landing.dart';
import '../model/calendar.dart';
import '../model/calendar_unit.dart';
import '../support/calendar_summary.dart';
import 'calendar_contract.dart';

/// The calendar editor owner's decision on [message] in [state], with its
/// [book]; undo steps keep only the units each edit changed.
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
          final (calendar: edited, :written) = writeEdit(calendar, landed.edit);
          if (UnitsChanged.of(calendar, edited, written) case final step?) {
            _showCalendar(edited);
            textChanged();
            record(step, null);
          }
          if (landed.gone case final gone?) events.add(SavedAsNew(gone));
        }
      case RenameCalendar(:final name):
        if (state.calendar case final calendar? when calendar.name != name) {
          _showCalendar(calendar.named(name));
          textChanged();
          record(
            NameChanged(calendar.name, name),
            typingIn(#name, calendar.name, name),
          );
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
  void undo(CalendarStep step) => switch (step) {
    UnitsChanged(:final before) => _bringBack(before),
    NameChanged(:final before) => _rename(before),
    TextReplaced(:final before) => _restore(before),
  };

  @override
  void redo(CalendarStep step) => switch (step) {
    UnitsChanged(:final after) => _bringBack(after),
    NameChanged(:final after) => _rename(after),
    TextReplaced(:final after) => _restore(after),
  };

  /// The calendar is named [name] again. A name step is only undone or
  /// redone on the calendar it was made on, so one shows.
  void _rename(String name) => _showCalendar(state.calendar!.named(name));

  /// The [units] of one side of an edit show again, stamped as an edit
  /// made when it was asked. A units step is only undone or redone on the
  /// calendar it was made on, so one shows.
  void _bringBack(Map<UnitKey, CalendarUnit?> units) => _showCalendar(
    unitsBroughtBack(state.calendar!, units, _requestAt, filed: _filed),
  );

  /// [back] shows again: a calendar stamped as an edit made when it was
  /// asked; a text that is no calendar as it is.
  void _restore(CalendarShown back) =>
      switch ((back.calendar, state.calendar)) {
        (final back?, final now?) => _showCalendar(
          broughtBack(back, now, _requestAt, filed: _filed),
        ),
        (final back?, null) => _showCalendar(back),
        (null, _) => reload(back.text),
      };

  @override
  void reload(String text) => state = CalendarState(
    text,
    Calendar.read(text),
    revision: state.revision + 1,
    status: book.status,
  );

  /// A backup restored: stamped as an edit, as an undo is, so a merge with
  /// the text it replaced keeps it.
  @override
  CalendarStep replaceText(String text) {
    final before = _shown;
    _restore((text: text, calendar: Calendar.read(text)));
    return TextReplaced(before, _shown);
  }

  @override
  SentText get sent => SentText(state.text, state.summary);

  @override
  TextSummary<Object?> summaryOfShown(String text) => state.summary;

  /// Only the page shows the calendar; nothing shows the text kept.
  @override
  bool get sendsAtOnce => false;

  /// The calendar as the file owner has it; `null` if its text is none.
  /// The book holds the summary this owner made of that text.
  Calendar? get _filed => (book.summary as CalendarSummary).calendar;

  /// What shows now.
  CalendarShown get _shown => (text: state.text, calendar: state.calendar);

  void _showCalendar(Calendar calendar) => state = CalendarState.of(
    calendar,
    revision: state.revision + 1,
    status: book.status,
  );

  void _settleStatus() {
    if (state.status == book.status) return;
    state = state.withStatus(book.status);
  }
}
