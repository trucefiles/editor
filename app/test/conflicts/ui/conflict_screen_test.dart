import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/conflicts/ui/conflict_banner.dart';
import 'package:truce_editor/folder_state/folder_state_controller.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/storage/app_storage.dart';

import '../../support.dart';

String _calendar(String events) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Test//EN\r\n'
    '${events}END:VCALENDAR\r\n';

String _event(String uid, String summary, String modified) =>
    'BEGIN:VEVENT\r\nUID:$uid\r\nDTSTAMP:${modified}Z\r\n'
    'LAST-MODIFIED:${modified}Z\r\nDTSTART;VALUE=DATE:20261105\r\n'
    'SUMMARY:$summary\r\nEND:VEVENT\r\n';

void main() {
  late Directory dir;
  late ProviderContainer container;

  /// Lets file work outside the test's fake time finish.
  Future<void> settle(WidgetTester tester, {bool Function()? until}) async {
    for (var step = 0; step < 100 && !(until?.call() ?? step > 5); step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// A calendar conflict whose copy has an older Swim and a new Gym,
  /// opened from a page as a conflict banner opens it.
  Future<void> pumpConflict(WidgetTester tester) async {
    final conflict = (await tester.runAsync(() async {
      dir = tempFolder();
      File(
        '${dir.path}/home.ics',
      ).writeAsStringSync(_calendar(_event('swim', 'Swim', '20261101T100000')));
      File('${dir.path}/home.sync-conflict-20261101-120000-ABCDEFG.ics')
          .writeAsStringSync(
            _calendar(
              _event('swim', 'Swim (old)', '20261101T080000') +
                  _event('gym', 'Gym', '20261101T080000'),
            ),
          );
      container = ProviderContainer(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          deviceIdProvider.overrideWithValue('0123456789abcdef'),
        ],
      );
      await saveFolders(container, [folderAt(dir)]);
      return (await container.read(folderContentsProvider.future))
          .conflicts
          .all
          .single;
    }))!;
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openConflict(context, conflict),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await settle(tester, until: () => find.text('Merge both').hasFound);
  }

  testWidgets('both merged: written, and a notice names what was replaced '
      'until dismissed', (tester) async {
    await pumpConflict(tester);

    await tester.tap(find.text('Merge both'));
    await tester.pumpAndSettle();
    expect(find.text('Merge both versions?'), findsOneWidget);
    await tester.tap(find.text('Keep'));
    String home() => File('${dir.path}/home.ics').readAsStringSync();
    await settle(tester, until: () => find.text('Open').hasFound);

    expect(home(), contains('SUMMARY:Gym\r\n'));
    expect(home(), contains('SUMMARY:Swim\r\n'));
    expect(
      find.text(
        'Merged. Newer changes replaced these older versions, which are in '
        'Backups: "Swim (old)".',
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('Dismiss'), findsOneWidget, reason: 'it stays');

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Merged.'), findsNothing);
  });
}
