import 'dart:async';

import 'package:flutter/material.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_files/truce_files.dart' show ViewSettings;

import 'calendar_clock.dart';
import 'calendar_editor_part.dart';
import 'calendar_start.dart';
import 'ui/calendar_name_field.dart';
import 'ui/calendar_page.dart';
import 'ui/event_links.dart';

/// How a calendar file's part shows on the page: its calendar page, and
/// its Add button, and Import from file in the file's menu; undo and redo
/// are the page's. What [_starts] asks of its file and its Add button
/// reach the page as its own [PageStarts].
final class CalendarEditorView extends EditorView {
  /// [_deviceZone] tells this device's time zone, for new events;
  /// [_starts] what calendar pages are asked to start with; [_openers]
  /// open the links and places events name; [_clock] is the calendars'
  /// clock.
  CalendarEditorView(
    this._part, {
    required this._deviceZone,
    required this._starts,
    required this._openers,
    required this._clock,
  });

  final CalendarEditorPart _part;
  final DeviceZone _deviceZone;
  final CalendarStarts _starts;
  final EventOpeners _openers;
  final CalendarClock _clock;
  final _pageStarts = PageStarts();

  @override
  Widget view(EditorHost host, {required bool autofocus}) {
    if (_starts.take((folder: host.folder, path: host.path))
        case final asked?) {
      _pageStarts.ask(asked);
    }
    return EventLinks(
      openers: _openers,
      hint: host.hint,
      child: CalendarPage(
        _part,
        clock: _clock,
        hint: host.hint,
        color: host.color,
        deviceZone: _deviceZone,
        starts: _pageStarts,
      ),
    );
  }

  /// The calendar's name, edited in place while it can be edited, with
  /// the file's [nameTitle] as its hint; otherwise, or for a text that is
  /// no calendar, [fileTitle].
  @override
  Widget title(
    BuildContext context,
    Widget fileTitle, {
    required String nameTitle,
  }) => _part.isEditing
      ? _forCalendar(
          CalendarNameField(_part, hint: nameTitle),
          otherwise: fileTitle,
        )
      : fileTitle;

  /// Import from a file, while a calendar can be edited.
  @override
  List<PopupMenuEntry<VoidCallback>> menu(
    BuildContext context,
    ViewSettings view,
  ) => [
    if (_part.isEditing && _part.owner.state.calendar != null)
      PopupMenuItem(
        value: () => unawaited(_part.importFile()),
        child: const Text('Import from file…'),
      ),
  ];

  /// Only for a calendar: a text that is no calendar has nothing to add.
  @override
  Widget? floatingButton(BuildContext context) => _forCalendar(
    FloatingActionButton(
      tooltip: 'Add',
      // Not a hero: no flight to other pages' buttons.
      heroTag: null,
      onPressed: () => _pageStarts.ask(const StartAdding()),
      child: const Icon(Icons.add),
    ),
  );

  /// [shown] while the part's text is a calendar, as it changes;
  /// [otherwise] while it is none.
  Widget _forCalendar(
    Widget shown, {
    Widget otherwise = const SizedBox.shrink(),
  }) => StreamBuilder(
    stream: _part.owner.changes,
    builder: (_, _) => _part.owner.state.calendar == null ? otherwise : shown,
  );
}
