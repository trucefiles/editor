import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_editor_part.dart';
import 'ui/calendar_page.dart';

/// How a calendar file's part shows on the page: its calendar page.
/// Adds nothing else to the page; undo and redo are the page's.
final class CalendarEditorView implements EditorView {
  /// [_deviceZone] tells this device's time zone, for new events;
  /// [_viewChoice] the view event calendars open in; [now] the time.
  CalendarEditorView(
    this._part, {
    required this._deviceZone,
    required this._viewChoice,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final CalendarEditorPart _part;
  final DeviceZone _deviceZone;
  final CalendarViewChoice _viewChoice;
  final DateTime Function() _now;

  @override
  Widget view(EditorHost host, {required bool autofocus}) => CalendarPage(
    _part,
    now: _now,
    hint: host.hint,
    deviceZone: _deviceZone,
    viewChoice: _viewChoice,
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
}
