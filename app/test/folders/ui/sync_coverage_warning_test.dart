import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_sync_coverage.dart';
import 'package:truce_editor/folders/ui/sync_coverage_warning.dart';
import 'package:truce_editor/platform/app_storage.dart';

import '../../support.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    SyncCoverage coverage, {
    bool includeUnknown = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        syncCoverageProvider.overrideWith((ref, folder) async => coverage),
      ],
      child: MaterialApp(
        home: SyncCoverageWarning(
          folderAt(tempFolder()),
          includeUnknown: includeUnknown,
          showFolderName: true,
        ),
      ),
    ),
  );

  testWidgets('warns about a folder that is not synced', (tester) async {
    await show(tester, SyncCoverage.notSynced);
    await tester.pump();

    expect(find.textContaining('Notes: Not inside a Syncthing'), findsOne);
  });

  testWidgets('says nothing about a synced folder', (tester) async {
    await show(tester, SyncCoverage.synced, includeUnknown: true);
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('mentions an unknown state only if asked', (tester) async {
    await show(tester, SyncCoverage.unknown);
    await tester.pump();
    expect(find.byType(Text), findsNothing);

    await show(tester, SyncCoverage.unknown, includeUnknown: true);
    await tester.pump();
    expect(find.textContaining("Can't check"), findsOne);
  });
}
