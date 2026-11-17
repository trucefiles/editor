import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

import 'page_harness.dart';

final _today = DateTime(2026, 11, 3);

/// A calendar file with [tasks], each a VTODO's lines without its
/// BEGIN and END.
String _withTasks(List<String> tasks) =>
    'BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:test\n'
    '${tasks.map((task) => 'BEGIN:VTODO\n$task\nEND:VTODO\n').join()}'
    'END:VCALENDAR\n';

final _rent = 'UID:rent\nSUMMARY:Pay rent\nDUE;VALUE=DATE:20261101';
final _call = 'UID:call\nSUMMARY:Call Ann\nDUE;VALUE=DATE:20261103';
final _gifts = 'UID:gifts\nSUMMARY:Buy gifts\nDUE;VALUE=DATE:20261120';
final _book = 'UID:book\nSUMMARY:Read a book';
final _bins =
    'UID:bins\nSUMMARY:Take out bins\nDUE;VALUE=DATE:20261102\n'
    'STATUS:COMPLETED\nCOMPLETED:20261102T080000Z\nPERCENT-COMPLETE:100';

/// The tasks view of a calendar of [tasks].
CalendarEditorPart _tasksPart(List<String> tasks, {bool readOnly = false}) =>
    calendarPart(
      _withTasks(tasks),
      readOnly: readOnly,
      kept: KeptView(CalendarViewKind.tasks),
    );

/// The row of the task titled [title].
Finder _row(String title) => find.widgetWithText(ListTile, title);

/// The box, showing [icon], of the task titled [title].
Finder _box(String title, IconData icon) =>
    find.descendant(of: _row(title), matching: find.byIcon(icon));

void main() {
  testWidgets('the tasks view groups what is due, and folds what is done', (
    tester,
  ) async {
    await pumpPage(
      tester,
      _tasksPart([_rent, _call, _gifts, _book, _bins]),
      today: _today,
    );

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final order = [
      'Overdue',
      'Pay rent',
      'Today',
      'Call Ann',
      'Later',
      'Buy gifts',
      'No date',
      'Read a book',
      'Done (1)',
    ].map(top).toList();
    expect(order, [...order]..sort());
    expect(find.text('Take out bins'), findsNothing, reason: 'folded');

    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Take out bins'), findsOne);
  });

  testWidgets('the tasks view is picked like any view, and kept', (
    tester,
  ) async {
    final kept = KeptView(CalendarViewKind.week);
    final part = calendarPart(_withTasks([_book]), kept: kept);
    await pumpPage(tester, part, today: _today);
    Future<void> pick(String view) async {
      await tester.tap(find.byTooltip('Pick a view'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(view).last);
      await tester.pumpAndSettle();
    }

    await pick('Tasks');
    expect(find.text('Read a book'), findsOne);
    expect(find.byTooltip('Next'), findsNothing);
    expect(kept.kind, CalendarViewKind.tasks);

    await pick('Week');
    expect(find.text('Read a book'), findsNothing, reason: 'no date');
    expect(find.byTooltip('Next'), findsOne);
  });

  testWidgets('with no tasks, the view says there is nothing to do', (
    tester,
  ) async {
    await pumpPage(tester, _tasksPart([]), today: _today);
    expect(find.text('Nothing to do.'), findsOne);
  });

  testWidgets('a box checks a task off, and a second tap opens it again', (
    tester,
  ) async {
    final part = _tasksPart([_call]);
    await pumpPage(tester, part, today: _today);

    await tester.tap(_box('Call Ann', Icons.check_box_outline_blank));
    await tester.pumpAndSettle();
    expect(calendarOf(part).tasks.single.series.done, isTrue);

    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();
    await tester.tap(_box('Call Ann', Icons.check_box));
    await tester.pumpAndSettle();
    expect(calendarOf(part).tasks.single.series.done, isFalse);
  });

  testWidgets('screen readers hear a box as a checkbox, checked once done', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester, _tasksPart([_call, _bins]), today: _today);
    await tester.tap(find.text('Done (1)'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(_box('Call Ann', Icons.check_box_outline_blank)),
      isSemantics(hasCheckedState: true, isChecked: false, hasTapAction: true),
    );
    expect(
      tester.getSemantics(_box('Take out bins', Icons.check_box)),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    semantics.dispose();
  });

  testWidgets('a task on a day of the month checks off from its box', (
    tester,
  ) async {
    final part = calendarPart(_withTasks([_call]));
    await pumpPage(tester, part, today: _today);

    await tester.tap(find.byTooltip('Mark as done'));
    await tester.pumpAndSettle();
    expect(calendarOf(part).tasks.single.series.done, isTrue);
  });

  testWidgets('a read-only calendar shows the boxes, but they do not check', (
    tester,
  ) async {
    await pumpPage(tester, _tasksPart([_call], readOnly: true), today: _today);
    expect(_box('Call Ann', Icons.check_box_outline_blank), findsOne);
    expect(find.byTooltip('Mark as done'), findsNothing);
  });

  testWidgets('Add in the tasks view opens the task form at once', (
    tester,
  ) async {
    final part = _tasksPart([]);
    await pumpPage(tester, part, today: _today);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('New task'), findsOne);
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Water');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final water = calendarOf(part).tasks.single.series;
    expect((water.summary, water.due), ('Water', null));
    expect(find.text('Water'), findsOne);
  });

  testWidgets(
    'Add elsewhere asks what to add; a task takes the time it adds at',
    (tester) async {
      final part = calendarPart(newCalendarText('Home'));
      await pumpPage(tester, part, today: _today);

      await tester.tap(find.byTooltip('Add'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Event'), findsOne);
      await pickNew(tester, 'Task');
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Water');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        calendarOf(part).tasks.single.series.due?.wall,
        DateTime.utc(2026, 11, 3, 9),
      );
    },
  );

  testWidgets('a tap on a task shows it; Delete takes it out', (tester) async {
    final part = _tasksPart([_call]);
    await pumpPage(tester, part, today: _today);

    await tester.tap(find.text('Call Ann'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOne);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(calendarOf(part).tasks.single.series.deleted, isTrue);
    expect(find.text('Nothing to do.'), findsOne);
  });

  testWidgets('a title changed on a task that only starts keeps its repeat', (
    tester,
  ) async {
    final part = _tasksPart([
      'UID:walk\nSUMMARY:Walk\nDTSTART;VALUE=DATE:20261103\n'
          'RRULE:FREQ=DAILY',
    ]);
    await pumpPage(tester, part, today: _today);

    await tester.tap(find.text('Walk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit all of them'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Run');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final run = calendarOf(part).tasks.single.series;
    expect((run.summary, run.repeats), ('Run', true));
  });

  testWidgets('Add in the tasks view of a health calendar lists its kinds', (
    tester,
  ) async {
    final part = calendarPart(
      newCalendarText('Me', health: true),
      kept: KeptView(CalendarViewKind.tasks),
    );
    await pumpPage(tester, part, today: _today);

    await tester.tap(find.byTooltip('Add'));
    await tester.pumpAndSettle();
    expect(find.text('Medication'), findsOne);
    expect(find.text('New task'), findsNothing);
  });

  testWidgets('a page asked to edit a task opens its form', (tester) async {
    final calendar = Calendar.read(_withTasks([_book]))!;
    final starts = CalendarStarts()
      ..ask(pageFile, EditTask.of(TaskEntry.undated(calendar.tasks.single)));
    await pumpPage(
      tester,
      calendarPart(calendar.text),
      today: _today,
      starts: starts,
    );
    expect(find.text('Edit task'), findsOne);
  });

  testWidgets('a task asked to edit that is gone gets a hint', (tester) async {
    final hints = <String>[];
    final starts = CalendarStarts()
      ..ask(pageFile, const EditTask('gone', null, due: null));
    await pumpPage(
      tester,
      calendarPart(_withTasks([_book])),
      today: _today,
      starts: starts,
      hints: hints,
    );
    expect(hints, hasLength(1));
    expect(find.text('Edit task'), findsNothing);
  });
}
