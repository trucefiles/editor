import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_editor_part.dart';
import 'calendar_start.dart';
import 'ui/calendar_page.dart';

/// How a calendar file's part shows on the page: its calendar page, and
/// its Add button; undo and redo are the page's. The page takes what
/// [_starts] asks of its file once its calendar shows.
final class CalendarEditorView implements EditorView {
  /// [_deviceZone] tells this device's time zone, for new events;
  /// [_viewChoice] the view event calendars open in; [_starts] what
  /// calendar pages are asked to start with; [now] the time.
  CalendarEditorView(
    this._part, {
    required this._deviceZone,
    required this._viewChoice,
    required this._starts,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final CalendarEditorPart _part;
  final DeviceZone _deviceZone;
  final CalendarViewChoice _viewChoice;
  final CalendarStarts _starts;
  final DateTime Function() _now;
  final _addAsks = AddAsks();

  @override
  Widget view(EditorHost host, {required bool autofocus}) => CalendarPage(
    _part,
    now: _now,
    hint: host.hint,
    color: host.color,
    deviceZone: _deviceZone,
    viewChoice: _viewChoice,
    addAsked: _addAsks,
    starts: _starts,
    start: () => _starts.take((folder: host.folder, path: host.path)),
  );

  @override
  List<Widget> actions(BuildContext context) => const [];

  @override
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  ) => const [];

  @override
  Map<SingleActivator, VoidCallback> get keys => const {};

  @override
  Widget? floatingButton(BuildContext context) => FloatingActionButton(
    tooltip: 'Add event',
    onPressed: _addAsks.ask,
    child: const Icon(Icons.add),
  );
}
