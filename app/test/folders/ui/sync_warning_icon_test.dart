import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folder_sync_status.dart';
import 'package:truce_editor/folders/ui/sync_warning_icon.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/platform/device_id.dart';

import '../../support.dart';

void main() {
  Future<void> show(WidgetTester tester, SyncStatus status) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          deviceIdProvider.overrideWithValue('0123456789abcdef'),
          syncStatusProvider.overrideWith((ref, folder) async => status),
        ],
        child: MaterialApp(home: SyncWarningIcon(folderAt(tempFolder()))),
      ),
    );
    await tester.pump();
  }

  testWidgets('signs a folder that is not synced', (tester) async {
    await show(tester, SyncStatus.notSynced);

    expect(find.byTooltip('Not inside a Syncthing folder'), findsOne);
  });

  testWidgets('shows nothing for a synced or unknown folder', (tester) async {
    await show(tester, SyncStatus.synced);
    expect(find.byType(Icon), findsNothing);

    await show(tester, SyncStatus.unknown);
    expect(find.byType(Icon), findsNothing);
  });
}
