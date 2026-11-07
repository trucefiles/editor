import 'dart:async';

import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_files/truce_files.dart';

import 'calendar_import_file.dart';

/// A calendar file's part of the file page: its editor owner, whether
/// the calendar can be edited here now, the import of a calendar file the
/// user picks, and the view its page opens in ([viewChoice]).
final class CalendarEditorPart extends FixedViewEditorPart {
  /// [_page] keeps the view picked on this device; [_pickFile] asks the
  /// user for a calendar file to import; [now] tells the time each edit
  /// is made at, and [startTimer] starts the editor's save clock (both
  /// fixed in tests).
  CalendarEditorPart(
    EditorStart start,
    this._page, {
    required this._pickFile,
    DateTime Function()? now,
    StartTimer? startTimer,
  }) : owner = calendarOwner(
         start.text,
         version: start.version,
         startTimer: startTimer,
       ),
       _now = now ?? DateTime.now,
       _kind = CalendarView.of(start.view).kind,
       super(readOnly: start.readOnly) {
    _importsDone = owner.events.listen((event) {
      if (event case ImportDone(:final report)) {
        _imports.add(FileImported(report));
      }
    });
  }

  /// The editor owner.
  final CalendarOwner owner;

  final EditorPage _page;

  CalendarViewKind _kind;

  /// The view the calendar's page opens in: the one picked last on it on
  /// this device, kept in the calendar's own view settings (the month
  /// until one is picked).
  late final CalendarViewChoice viewChoice = CalendarViewChoice(
    last: () => _kind,
    keep: (kind) async {
      _kind = kind;
      _page.keepView((view) => CalendarView.of(view).withKind(kind).settings);
    },
  );

  final PickCalendarFile _pickFile;

  final DateTime Function() _now;

  final _imports = StreamController<ImportOutcome>.broadcast();

  late final StreamSubscription<CalendarOwnerEvent> _importsDone;

  /// [owner] as the file page sees it (core's editor contract): each
  /// request stamped with when it was made.
  @override
  late final PageEditor editor = OwnerView(
    owner,
    input: (request) => CalendarRequest(request, at: _at()),
    state: (state) => state.status,
    event: (event) => switch (event) {
      CalendarNotice(:final notice) => notice,
      SavedAsNew() || ImportDone() => null,
    },
  );

  /// What was gone each time an edit was saved as a new event instead.
  Stream<GoneMeanwhile> get savedAsNew => owner.events.expand(
    (event) => [if (event case SavedAsNew(:final gone)) gone],
  );

  /// The user's [edit], made now; dropped while the calendar can't be
  /// edited (e.g. a form opened before it turned read only). Whether it
  /// was made.
  bool edit(CalendarEdit Function(DateTime at) edit) {
    if (!isEditing) return false;
    owner.send(EditCalendar(edit(_at()), newUid: newUid()));
    return true;
  }

  /// What came of each import the user asked for ([importFile]).
  Stream<ImportOutcome> get imports => _imports.stream;

  /// Imports the events of a calendar file the user picks, as one edit;
  /// dropped if they pick none, while the calendar can't be edited then,
  /// or once the part is disposed. What came of it is told by [imports].
  Future<void> importFile() async {
    final picked = await _pickFile();
    if (_imports.isClosed) return;
    switch (picked) {
      case Ok(value: final bytes?) when isEditing:
        owner.send(ImportEvents(bytes, at: _at()));
      case Err():
        _imports.add(const FileNotRead());
      case Ok():
    }
  }

  /// The user names the calendar [name] (none if empty); dropped while
  /// it can't be edited. Whether it was made.
  bool rename(String name) {
    if (!isEditing) return false;
    owner.send(RenameCalendar(name));
    return true;
  }

  DateTime _at() => _now().toUtc();

  @override
  void dispose() {
    unawaited(_importsDone.cancel());
    unawaited(_imports.close());
    super.dispose();
  }
}
