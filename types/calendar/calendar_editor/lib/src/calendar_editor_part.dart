import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// A calendar file's part of the file page: its editor owner, and
/// whether the calendar can be edited here now. Keeps nothing of how the
/// calendar shows.
final class CalendarEditorPart extends FixedViewEditorPart {
  /// [now] tells the time each edit is made at, and [startTimer] starts
  /// the editor's save clock (both fixed in tests).
  CalendarEditorPart(
    EditorStart start, {
    DateTime Function()? now,
    StartTimer? startTimer,
  }) : owner = calendarOwner(
         start.text,
         version: start.version,
         startTimer: startTimer,
       ),
       _now = now ?? DateTime.now,
       super(readOnly: start.readOnly);

  /// The editor owner.
  final CalendarOwner owner;

  final DateTime Function() _now;

  /// [owner] as the file page sees it (core's editor contract): each
  /// request stamped with when it was made.
  @override
  late final PageEditor editor = OwnerView(
    owner,
    input: (request) => CalendarRequest(request, at: _at()),
    state: (state) => state.status,
    event: (event) => event.notice,
  );

  /// The user's [edit], made now; dropped while the calendar can't be
  /// edited (e.g. a form opened before it turned read only). Whether it
  /// was made.
  bool edit(CalendarEdit Function(DateTime at) edit) {
    if (!isEditing) return false;
    owner.send(EditCalendar(edit(_at())));
    return true;
  }

  DateTime _at() => _now().toUtc();
}
