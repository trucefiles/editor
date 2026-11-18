import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:truce_calendar_alerts/truce_calendar_alerts.dart';
import 'package:truce_editor/alerts/ring_state_store.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../support.dart';
import 'alert_samples.dart';

void main() {
  test('keeps the ring state in app storage, read back as written', () async {
    final storage = AppStorage(tempFolder().path);
    final alert = eventAlert('Dentist', at: DateTime.utc(2026, 11, 17, 9));
    final kept = RingState.none.copyWith(
      handed: {alert.id: (number: 1, alert: alert)},
      nextNumber: 2,
      plans: {
        alert.file: (
          version: '7',
          day: DateTime(2026, 11, 17),
          zone: 'Europe/Berlin',
        ),
      },
    );

    await RingStateStore.of(storage).save(kept);
    final read = await RingStateStore.of(storage).load();

    expect(read, kept);
  });

  test('nothing kept, or nothing readable, is no state', () async {
    final storage = AppStorage(tempFolder().path);
    expect((await RingStateStore.of(storage).load()).handed, isEmpty);

    File('${storage.settingsPath}/ring_state.json')
        .writeCreatingFolders('{broken');
    expect((await RingStateStore.of(storage).load()).handed, isEmpty);
  });

  test("a state that can't be written is logged, not thrown", () async {
    final folder = tempFolder();
    // Where the file should go is a file, not a folder.
    final blocked = File('${folder.path}/blocked')..writeAsStringSync('');
    final logged = <String>[];
    final records = Logger.root.onRecord.listen(
      (record) => logged.add(record.message),
    );
    addTearDown(records.cancel);

    await RingStateStore(File('${blocked.path}/ring_state.json'))
        .save(RingState.none);

    expect(logged, [startsWith("Couldn't keep the alerts' ring state")]);
  });
}
