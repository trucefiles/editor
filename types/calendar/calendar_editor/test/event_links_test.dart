import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';

/// An occurrence at [location] with [description].
EventOccurrence _event({required String location, String description = ''}) {
  final calendar = applyEdit(
    Calendar.read(newCalendarText('Home'))!,
    AddItem(
      'a',
      EventDraft(
        summary: 'Meeting',
        start: Floating(DateTime.utc(2026, 11, 3, 17)),
        end: Floating(DateTime.utc(2026, 11, 3, 18)),
        location: location,
        description: description,
      ),
      at: DateTime.utc(2026, 11),
    ),
  );
  return occurrences(
        calendar,
        DateTime(2026, 11, 3),
        DateTime(2026, 11, 4),
      ).single
      as EventOccurrence;
}

void main() {
  final opened = <Object>[];
  final hints = <String>[];
  var opens = true;
  setUp(() {
    opened.clear();
    hints.clear();
    opens = true;
  });

  /// Notes [what] as opened; whether it could be.
  Future<bool> record(Object what) async {
    opened.add(what);
    return opens;
  }

  /// Shows [occurrence]'s sheet, opened below [EventLinks] if [links].
  Future<void> showSheet(
    WidgetTester tester,
    EventOccurrence occurrence, {
    bool links = true,
  }) async {
    final button = Builder(
      builder: (context) => TextButton(
        onPressed: () => showOccurrenceSheet<void>(context, occurrence, []),
        child: const Text('Show'),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: links
              ? EventLinks(
                  openers: EventOpeners(openLink: record, openPlace: record),
                  hint: hints.add,
                  child: button,
                )
              : button,
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tapOnText(find.textRange.ofSubstring(text));
    await tester.pumpAndSettle();
  }

  testWidgets('a link in the notes opens as a link', (tester) async {
    await showSheet(
      tester,
      _event(location: 'Office', description: 'Join www.example.org'),
    );

    await tapText(tester, 'www.example.org');

    expect(opened, [Uri.parse('http://www.example.org')]);
  });

  testWidgets('a place opens in a maps app', (tester) async {
    await showSheet(tester, _event(location: 'Town hall, Main St 1'));

    await tapText(tester, 'Town hall');

    expect(opened, ['Town hall, Main St 1']);
  });

  testWidgets('a place that is a link opens as a link', (tester) async {
    await showSheet(tester, _event(location: 'https://meet.example.org/x'));

    await tapText(tester, 'meet.example.org');

    expect(opened, [Uri.parse('https://meet.example.org/x')]);
  });

  testWidgets('a hint says when nothing could open it', (tester) async {
    opens = false;
    await showSheet(tester, _event(location: 'Town hall'));

    await tapText(tester, 'Town hall');

    expect(hints, ['No app could show Town hall']);
  });

  testWidgets('without links from above, the sheet shows plain text', (
    tester,
  ) async {
    await showSheet(tester, _event(location: 'Town hall'), links: false);

    await tapText(tester, 'Town hall');

    expect(opened, isEmpty);
  });
}
