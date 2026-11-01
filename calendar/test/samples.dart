/// Calendar texts the tests read, as other apps write them (`\n` breaks,
/// as the app's text model gives them).
library;

/// A calendar as a typical export has it: a time zone, a series with a
/// changed occurrence (not next to it), a folded line, a task and an
/// unknown property.
const exported = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example Corp//Calendar 1.0//EN
X-WR-CALNAME:Family
BEGIN:VTIMEZONE
TZID:Europe/Berlin
BEGIN:STANDARD
DTSTART:19701025T030000
TZOFFSETFROM:+0200
TZOFFSETTO:+0100
END:STANDARD
END:VTIMEZONE
BEGIN:VEVENT
UID:swim@example.com
DTSTAMP:20261001T080000Z
LAST-MODIFIED:20261001T080000Z
SEQUENCE:0
DTSTART;TZID=Europe/Berlin:20261005T170000
DTEND;TZID=Europe/Berlin:20261005T180000
RRULE:FREQ=WEEKLY;BYDAY=MO
SUMMARY:Swimming
DESCRIPTION:Bring towels and the blue bag\\, and do not forget the membersh
 ip card at the desk
X-EXAMPLE-COLOR:blue
END:VEVENT
BEGIN:VTODO
UID:todo@example.com
SUMMARY:Buy paint
END:VTODO
BEGIN:VEVENT
UID:dentist@example.com
DTSTAMP:20261002T080000Z
DTSTART:20261110T090000
DTEND:20261110T100000
SUMMARY:Dentist
END:VEVENT
BEGIN:VEVENT
UID:swim@example.com
RECURRENCE-ID;TZID=Europe/Berlin:20261012T170000
DTSTAMP:20261003T080000Z
LAST-MODIFIED:20261003T080000Z
DTSTART;TZID=Europe/Berlin:20261012T180000
DTEND;TZID=Europe/Berlin:20261012T190000
SUMMARY:Swimming (late)
END:VEVENT
END:VCALENDAR
''';

/// A calendar of one all-day event and no time zone.
const birthday = '''BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Truce Editor//Calendar//EN
X-WR-CALNAME:Birthdays
BEGIN:VEVENT
UID:ann@truce
DTSTAMP:20261001T080000Z
LAST-MODIFIED:20261001T080000Z
SEQUENCE:0
DTSTART;VALUE=DATE:20200312
DTEND;VALUE=DATE:20200313
RRULE:FREQ=YEARLY
SUMMARY:Ann
END:VEVENT
END:VCALENDAR
''';
