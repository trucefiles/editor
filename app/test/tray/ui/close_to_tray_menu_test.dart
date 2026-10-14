import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/platform/app_storage.dart';
import 'package:truce_editor/tray/tray_wiring.dart';
import 'package:truce_editor/tray/ui/close_to_tray_menu.dart';

import '../../support.dart';
import '../fakes.dart';

void main() {
  late FakeTray tray;
  late FakeWindow window;

  setUp(() {
    tray = FakeTray();
    window = FakeWindow();
  });

  Future<void> pumpMenu(WidgetTester tester, {bool withTray = true}) async {
    final storage = AppStorage(tempFolder().path);
    await tester.runAsync(
      () => tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStorageProvider.overrideWithValue(storage),
            systemTrayProvider.overrideWithValue(withTray ? tray : null),
            appWindowProvider.overrideWithValue(window),
          ],
          child: MaterialApp(
            home: Scaffold(appBar: AppBar(actions: const [CloseToTrayMenu()])),
          ),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<bool>));
    await tester.pumpAndSettle();
  }

  /// Taps the setting and lets its file write finish.
  Future<void> toggle(WidgetTester tester) async {
    await tester.tap(find.text('Keep running in tray'));
    await tester.pumpAndSettle();
    // Each file step completes outside the test's fake time.
    for (var step = 0; step < 10; step++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump();
    }
  }

  testWidgets('turns keeping running in the tray off and on', (tester) async {
    await pumpMenu(tester);
    await openMenu(tester);
    expect(find.byIcon(Icons.check_box), findsOneWidget);

    await toggle(tester);
    expect(window.hideOnClose, isFalse);
    expect(tray.shown, isFalse);

    await openMenu(tester);
    expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
    await toggle(tester);
    expect(window.hideOnClose, isTrue);
  });

  testWidgets('says when no tray can take the icon', (tester) async {
    tray.hasTray = false;
    await pumpMenu(tester);
    await openMenu(tester);

    expect(find.text('No tray on this desktop: closing quits'), findsOneWidget);
  });

  testWidgets('has no menu where the platform has no tray', (tester) async {
    await pumpMenu(tester, withTray: false);

    expect(find.byType(PopupMenuButton<bool>), findsNothing);
  });
}
