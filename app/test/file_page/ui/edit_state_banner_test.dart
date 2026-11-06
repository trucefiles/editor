import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/file_page/file_controller.dart';
import 'package:truce_editor/file_page/ui/edit_state_banner.dart';
import 'package:truce_files/truce_files.dart';

import '../file_fixture.dart';

void main() {
  for (final reachable in [true, false]) {
    testWidgets('once the folder is removed, stays telling the file is read '
        'only and copies its latest text (folder reachable: $reachable)', (
      tester,
    ) async {
      late FileFixture fixture;
      late FileSession session;
      await tester.runAsync(() async {
        fixture = await FileFixture.create();
        session = fixture.session();
        await fixture.removeFirstFolder();
        session.type('mine ');
        await session.secure(.hide);
      });
      expect(session.state, isA<Stopped>());
      final controller = FileController(
        session,
        reach: () => Reach.reachable,
        reachSettled: () async => Reach.reachable,
        backUp: (_) async => const Ok(null),
        delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
        settingsOf: (_) => FileSettings.defaults,
        editSettings: (_, _) async {},
        endWait: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListenableBuilder(
                listenable: controller,
                builder: (_, _) => EditStateBanner(
                  controller,
                  onClose: () {},
                  folderReachable: reachable,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining("so you can't edit it anymore"), findsOne);
      await tester.tap(find.text('Copy text'));
      await tester.pumpAndSettle();
      expect(copied, [session.text]);
      expect(copied.single, startsWith('mine '));
      expect(find.text('Copied.'), findsOne);
    });
  }
}
