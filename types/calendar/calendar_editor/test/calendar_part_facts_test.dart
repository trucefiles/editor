import 'package:flutter_test/flutter_test.dart';
import 'package:truce_files/truce_files.dart';

import 'page_harness.dart';

void main() {
  test('tells the events and tasks of the calendar it shows, and sends '
      'nothing', () {
    final part = calendarPart(
      [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'BEGIN:VEVENT',
        'UID:a',
        'DTSTART;VALUE=DATE:20261101',
        'END:VEVENT',
        'BEGIN:VTODO',
        'UID:t',
        'END:VTODO',
        'BEGIN:VTODO',
        'UID:u',
        'END:VTODO',
        'END:VCALENDAR',
        '',
      ].join('\n'),
    );
    addTearDown(part.dispose);
    final sent = <Object?>[];
    part.editor.events.listen(sent.add);
    final before = part.editor.state;

    final facts = part.facts();

    expect(
      [for (final fact in facts.cast<TextFact>()) (fact.label, fact.text)],
      [('Events', '1'), ('Tasks', '2')],
    );
    expect(part.editor.state, same(before));
    expect(sent, isEmpty);
  });

  test('tells nothing while the text is no calendar', () {
    final part = calendarPart('no calendar');
    addTearDown(part.dispose);

    expect(part.facts(), isEmpty);
  });
}
