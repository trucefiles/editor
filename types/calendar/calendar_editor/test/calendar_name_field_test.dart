import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';

import 'page_harness.dart';

/// The view of [part], as the file page shows its parts.
CalendarEditorView _viewOf(CalendarEditorPart part) => CalendarEditorView(
  part,
  deviceZone: () async => null,
  viewChoice: KeptView().choice,
  starts: CalendarStarts(),
);

/// Shows [part]'s title in an app bar, as the file page does, the file's
/// [title] where the type has none; [nameTitle] is the file name's.
Future<void> _pumpTitle(
  WidgetTester tester,
  CalendarEditorPart part, {
  String title = 'Calendar',
  String nameTitle = 'Calendar',
}) {
  addTearDown(() => unawaited(part.editor.close()));
  final view = _viewOf(part);
  return tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: view.title(context, Text(title), nameTitle: nameTitle),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the name is typed in the title; with none, the file name '
      'shows as a hint', (tester) async {
    final part = calendarPart(newCalendarText(''));
    await _pumpTitle(tester, part);
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).decoration!.hintText, 'Calendar');

    await tester.enterText(field, 'Family');
    await tester.pump();
    expect(calendarOf(part).name, 'Family');
    expect(part.owner.state.status.canUndo, isTrue);
  });

  testWidgets('an undo of the name shows in the title', (tester) async {
    final part = calendarPart(newCalendarText('Home'));
    await _pumpTitle(tester, part);
    await tester.enterText(find.byType(TextField), 'Home and work');
    await tester.pump();

    part.editor.send(const Undo());
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Home',
    );
  });

  testWidgets('a calendar that is read only, or no calendar, has no name '
      'to edit', (tester) async {
    for (final part in [
      calendarPart(newCalendarText('Home'), readOnly: true),
      calendarPart('no calendar'),
    ]) {
      await _pumpTitle(tester, part, title: 'a');
      expect(find.byType(TextField), findsNothing);
      expect(find.text('a'), findsOneWidget);
    }
  });

  testWidgets('a cleared name shows the file name as the hint, not the old '
      'name', (tester) async {
    final part = calendarPart(newCalendarText('Home'));
    await _pumpTitle(tester, part, title: 'Home', nameTitle: 'Work');
    final field = find.byType(TextField);
    await tester.enterText(field, '');
    await tester.pump();
    expect(tester.widget<TextField>(field).decoration!.hintText, 'Work');
  });

  testWidgets("with no name of ours, the standard's NAME is the hint", (
    tester,
  ) async {
    final part = calendarPart(
      newCalendarText('')
          .replaceFirst('END:VCALENDAR', 'NAME:Arbeit\nEND:VCALENDAR'),
    );
    await _pumpTitle(tester, part, title: 'Arbeit', nameTitle: 'work');
    final field = find.byType(TextField);
    expect(tester.widget<TextField>(field).decoration!.hintText, 'Arbeit');
    expect(tester.widget<TextField>(field).controller!.text, '');
  });
}
