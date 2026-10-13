import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_sync_root.dart';
import 'package:truce_editor/folders/ui/sync_root_warning.dart';
import 'package:truce_editor/platform/app_storage.dart';

import '../../support.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    SyncRootSearch search, {
    bool includeUnknown = false,
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
        syncRootProvider.overrideWith((ref, folder) async => search),
      ],
      child: MaterialApp(
        home: SyncRootWarning(
          folderAt(tempFolder()),
          includeUnknown: includeUnknown,
          showFolderName: true,
        ),
      ),
    ),
  );

  testWidgets('warns about a folder that is not synced', (tester) async {
    await show(tester, const SyncRootMissing());
    await tester.pump();

    expect(find.textContaining('Notes: Not inside a Syncthing'), findsOne);
  });

  testWidgets('says nothing about a synced folder', (tester) async {
    await show(tester, const SyncRootFound('/sync'), includeUnknown: true);
    await tester.pump();

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('mentions an unknown state only if asked', (tester) async {
    await show(tester, const SyncRootUnknown());
    await tester.pump();
    expect(find.byType(Text), findsNothing);

    await show(tester, const SyncRootUnknown(), includeUnknown: true);
    await tester.pump();
    expect(find.textContaining("Can't check"), findsOne);
  });
}
