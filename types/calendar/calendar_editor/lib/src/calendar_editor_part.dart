import 'dart:async';

import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

/// A calendar file's part of the file page: its editor owner, and
/// whether the calendar can be edited here now. Keeps nothing of how the
/// calendar shows.
final class CalendarEditorPart implements EditorPart {
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
       _readOnly = start.readOnly;

  /// The editor owner.
  final CalendarOwner owner;

  final DateTime Function() _now;

  @override
  late final PageEditor editor = _CalendarPageEditor(owner, at: _at);

  final _changes = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get changes => _changes.stream;

  bool _readOnly;

  /// The user's [edit], made now; dropped while the calendar can't be
  /// edited (e.g. a form opened before it turned read only). Whether it
  /// was made.
  bool edit(CalendarEdit Function(DateTime at) edit) {
    if (_readOnly) return false;
    owner.send(EditCalendar(edit(_at())));
    return true;
  }

  DateTime _at() => _now().toUtc();

  @override
  void showReadOnly({required bool readOnly}) {
    if (readOnly == _readOnly) return;
    _readOnly = readOnly;
    _changes.add(null);
  }

  @override
  bool get isEditing => !_readOnly;

  @override
  void viewChanged(ViewSettings view) {}

  @override
  void dispose() => unawaited(_changes.close());
}

/// The calendar editor owner [_owner] as the file page sees it (core's
/// editor contract): each request stamped with when it was made.
final class _CalendarPageEditor implements PageEditor {
  _CalendarPageEditor(this._owner, {required this._at});

  final CalendarOwner _owner;
  final DateTime Function() _at;

  @override
  void send(EditorRequest input) =>
      _owner.send(CalendarRequest(input, at: _at()));

  @override
  EditorStatus get state => _owner.state.status;

  @override
  late final Stream<EditorStatus> changes = _owner.changes
      .map((state) => state.status)
      .distinct();

  @override
  Stream<EditorNotice> get events => _owner.events.map((event) => event.notice);

  @override
  Future<void> close() => _owner.close();
}
