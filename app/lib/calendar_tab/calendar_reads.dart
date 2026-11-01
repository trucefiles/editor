import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_documents/truce_documents.dart';

/// A calendar document as listed: the [document] and its [version] with
/// the copies read into it.
typedef ListedCalendar = ({Document document, Version version});

/// Reads calendar documents for the Calendar tab, merged with their
/// copies, as every read of them is; a calendar is read again only once
/// its version changes.
final class CalendarReads {
  CalendarReads(this._files);

  final FolderFiles _files;

  /// The calendars of the last [readAll], by key, with the version read.
  var _read = <DocumentKey, ({Version version, Calendar? calendar})>{};

  /// Each of [listed]'s calendars, read anew where its version is new; a
  /// file that can't be read or is no calendar is left out. Keeps only
  /// these, so calendars gone are dropped.
  Future<Map<Document, Calendar>> readAll(List<ListedCalendar> listed) async {
    final read = {
      for (final (:document, :version) in listed)
        document.key: switch (_read[document.key]) {
          final known? when known.version == version => known,
          _ => (version: version, calendar: await _calendarOf(document)),
        },
    };
    _read = read;
    return {
      for (final (:document, version: _) in listed)
        document: ?read[document.key]?.calendar,
    };
  }

  Future<Calendar?> _calendarOf(Document document) async =>
      switch (await _files.of(document.folder).reload(document)) {
        Ok(:final value) => Calendar.read(value.text),
        Err() => null,
      };
}
