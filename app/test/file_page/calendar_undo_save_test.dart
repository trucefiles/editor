import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:truce_calendar/truce_calendar.dart';
import 'package:truce_calendar_editor/truce_calendar_editor.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/file_pages.dart';
import 'package:truce_files/truce_files.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_text_editing/truce_text_editing.dart';

import '../support.dart';
import 'file_fixture.dart';

/// An undo of a calendar edit and what the folder gets of it.
void main() {
  late FileFixture fixture;
  late FilePage page;
  late String start;

  CalendarEditorPart part() => page.part as CalendarEditorPart;

  File onDisk() => File('${fixture.dirs[0].path}/Home.ics');

  setUp(() async {
    fixture = await FileFixture.create();
    start = applyEdit(
      Calendar.read(newCalendarText('Home'))!,
      AddItem(
        'call@t',
        EventDraft(
          summary: 'Call',
          start: Floating(DateTime.utc(2026, 11, 3, 9)),
          end: Floating(DateTime.utc(2026, 11, 3, 10)),
        ),
        at: DateTime.utc(2026, 11),
      ),
    ).text;
    final type = appFileTypes().newFileChoices
        .firstWhere((made) => made.label == 'Calendar')
        .type;
    final file = (await fixture.files[fixture.folders[0].id]!.create(
      'Home',
      type: appTextType(type),
      text: start,
    )).value;
    page = FilePages(
      create: fixture.createFile,
      move: fixture.moveFile,
      delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
      settingsOf: (_) => FileSettings.defaults,
      editSettings: (_, _) async {},
      filesOf: (folder) => fixture.files[folder.id]!,
      draftsOf: (folder) => fixture.drafts[folder.id]!,
      reachOf: (_) => Reach.reachable,
      reachSettled: (_) async => Reach.reachable,
      openEdits: OpenEdits(),
      fileClosed: () {},
      endWait: const Duration(seconds: 1),
      arrivals: noArrivals(),
    ).open(file, type: appTextType(type), withFile: (_) async {});
  });

  void deleteCall() =>
      part().edit((at) => DeleteItem(UidKey.event('call@t'), at: at));

  test('a delete undone before the folder got it writes nothing, even after '
      'a draft', () async {
    final bytes = onDisk().readAsStringSync();
    final written = onDisk().lastModifiedSync();
    deleteCall();
    page.session.draftNow();
    await pumpEventQueue();
    part().editor.send(const Undo());

    await page.close();

    expect(onDisk().readAsStringSync(), bytes);
    expect(onDisk().lastModifiedSync(), written, reason: 'no write');
  });

  test('a delete undone after the folder got it is written again, the call '
      'back', () async {
    final bytes = onDisk().readAsStringSync();
    deleteCall();
    await page.session.secure(SecureReason.hide);
    expect(onDisk().readAsStringSync(), isNot(bytes));
    part().editor.send(const Undo());

    await page.close();

    final text = onDisk().readAsStringSync().replaceAll('\r\n', '\n');
    final call = Calendar.read(text)!.eventOf('call@t');
    expect(call!.series.deleted, isFalse);
  });
}
