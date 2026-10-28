import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/ui/folder_notices_view.dart';
import 'package:truce_editor/folders/ui/folder_warning_icon.dart';
import 'package:truce_editor/storage/app_storage.dart';
import 'package:truce_editor/storage/device_id.dart';
import 'package:truce_editor/sync_tool/base_folder_following.dart';

import '../../support.dart';

void main() {
  Future<void> show(
    WidgetTester tester,
    List<FolderNotice> notices,
    Widget Function(Widget) wrap,
  ) async {
    final folder = folderAt(tempFolder());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStorageProvider.overrideWithValue(AppStorage(tempFolder().path)),
          deviceIdProvider.overrideWithValue('0123456789abcdef'),
          folderNoticesProvider.overrideWith((ref, location) async => notices),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: wrap(FolderNoticesView(folder)),
            appBar: AppBar(actions: [FolderWarningIcon(folder)]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Widget asIs(Widget view) => view;

  testWidgets('lists every notice on the folders screen', (tester) async {
    await show(tester, const [
      NotSyncedNotice(),
      PolledNotice(Duration(seconds: 10)),
    ], asIs);

    expect(find.textContaining('Not inside a Syncthing folder.'), findsOne);
    expect(find.textContaining('checked for changes every 10 s'), findsOne);
  });

  testWidgets('says nothing without notices', (tester) async {
    await show(tester, const [], asIs);

    expect(find.byType(Text), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('shows the warning sign only for warnings', (tester) async {
    await show(tester, const [
      SyncUnknownNotice(),
      PolledNotice(Duration(seconds: 10)),
    ], (_) => const SizedBox());
    expect(find.byIcon(Icons.warning_amber), findsNothing);

    await show(tester, const [NotSyncedNotice()], (_) => const SizedBox());
    expect(find.byIcon(Icons.warning_amber), findsOne);
  });
}
