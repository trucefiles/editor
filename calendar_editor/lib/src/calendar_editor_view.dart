import 'package:flutter/material.dart';
import 'package:truce_document_page/truce_document_page.dart';
import 'package:truce_documents/truce_documents.dart';

import 'calendar_editor_part.dart';
import 'ui/calendar_page.dart';
import 'ui/event_actions.dart';

/// How a calendar document's part shows on the page: its calendar page.
/// Adds nothing else to the page; undo and redo are the page's.
final class CalendarEditorView implements EditorView {
  /// [_deviceZone] tells this device's time zone, for new events.
  CalendarEditorView(
    this._part, {
    required this._deviceZone,
    DateTime Function()? today,
  }) : _today = today ?? DateTime.now;

  final CalendarEditorPart _part;
  final DeviceZone _deviceZone;
  final DateTime Function() _today;

  @override
  Widget view(EditorHost host, {required bool autofocus}) => CalendarPage(
    _part,
    today: _today(),
    hint: host.hint,
    deviceZone: _deviceZone,
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
