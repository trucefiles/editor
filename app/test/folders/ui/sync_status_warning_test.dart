import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_sync_status.dart';
import 'package:truce_editor/folders/ui/sync_status_warning.dart';
import 'package:truce_editor/platform/app_storage.dart';

import '../../support.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    SyncStatus status, {
    bool includeUnknown = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        syncStatusProvider.overrideWith((ref, folder) async => status),
      ],
      child: MaterialApp(
        home: SyncStatusWarning(
          folderAt(tempFolder()),
          includeUnknown: includeUnknown,
          showFolderName: true,
        ),
      ),
    ),
  );

  testWidgets('warns about a folder that is not synced', (tester) async {
    await show(tester, SyncStatus.notSynced);
    await tester.pump();

    expect(find.textContaining('Notes: Not inside a Syncthing'), findsOne);
  });

  testWidgets('says nothing about a synced folder', (tester) async {
    await show(tester, SyncStatus.synced, includeUnknown: true);
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('mentions an unknown state only if asked', (tester) async {
    await show(tester, SyncStatus.unknown);
    await tester.pump();
    expect(find.byType(Text), findsNothing);

    await show(tester, SyncStatus.unknown, includeUnknown: true);
    await tester.pump();
    expect(find.textContaining("Can't check"), findsOne);
  });
}
