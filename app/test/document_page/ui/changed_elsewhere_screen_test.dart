import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/document_page/document_controller.dart';
import 'package:truce_editor/document_page/document_session.dart';
import 'package:truce_editor/document_page/ui/edit_state_banner.dart';
import 'package:truce_editor/documents/delete_failure.dart';

import '../../support.dart';
import '../document_fixture.dart';

void main() {
  late DocumentFixture fixture;
  late DocumentSession session;

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

  /// A session whose edits wait on the device while the file changed
  /// elsewhere; the banner offers to compare, which is opened.
  Future<void> pumpCompare(WidgetTester tester) async {
    await tester.runAsync(() async {
      fixture = await DocumentFixture.create();
      session = fixture.session()..type('mine ');
      await fixture.editElsewhere('theirs\n');
      await session.secure(.hide);
    });
    expect(session.status, isA<ChangedElsewhere>());
    final controller = DocumentController(
      session,
      reachSettled: () async => Reach.reachable,
      backUp: (_) async => const Ok(null),
      canEdit: () => true,
      delete: (_, _) async => const Err(DeleteNotDone(StoreError.notFound)),
      editSettings: (_, _) async {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, _) => EditStateBanner(controller, onClose: () {}),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Compare'));
    await settle(tester);
  }

  /// The document as changed elsewhere again, found by a scan.
  Future<void> changedAgain(WidgetTester tester, String text) async {
    await tester.runAsync(() async {
      final latest = await fixture.editElsewhere(text);
      session.observe(contentsFinding([latest.document]));
      // The file owner reads the new version itself.
      await eventually(
        () => switch (session.status) {
          ChangedElsewhere(:final theirs) => theirs.text == text,
          _ => session.text == text,
        },
      );
    });
    await settle(tester);
  }

  testWidgets('a change from elsewhere opens both versions', (tester) async {
    await pumpCompare(tester);

    expect(find.text('Current version'), findsOneWidget);
    expect(find.text('Your edits'), findsOneWidget);
    // Each version's pane shows the other's lines too, as removed.
    expect(find.textContaining('mine'), findsNWidgets(2));
    expect(find.textContaining('theirs'), findsNWidgets(2));
  });

  testWidgets('keeping the current version closes the comparison', (
    tester,
  ) async {
    await pumpCompare(tester);

    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep'));
    await settle(tester, until: () => session.text == 'theirs\n');

    expect(session.text, 'theirs\n');
    expect(find.text('Your edits'), findsNothing);
    expect(find.text('Compare'), findsNothing);
  });

  testWidgets('keeps both while the user cancels', (tester) async {
    await pumpCompare(tester);

    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('A backup of both stays'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(session.status, isA<ChangedElsewhere>());
    expect(find.text('Your edits'), findsOneWidget);
  });

  testWidgets('settled under the dialog: closes itself, not the dialog', (
    tester,
  ) async {
    await pumpCompare(tester);
    await tester.tap(find.text('Keep this').first);
    await tester.pumpAndSettle();

    // The file now holds the edits: nothing left to choose.
    await changedAgain(tester, 'mine one\n');
    expect(find.text('Your edits'), findsNothing);
    expect(find.text('Keep this version?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await settle(tester);

    // The choice was settled meanwhile: the late tap changes nothing.
    expect(session.text, 'mine one\n');
    expect(session.status, isA<InStep>());
  });

  testWidgets('a newer version under the dialog is never overwritten', (
    tester,
  ) async {
    await pumpCompare(tester);
    await tester.tap(find.text('Keep this').last);
    await tester.pumpAndSettle();

    await changedAgain(tester, 'theirs, newer\n');
    await tester.tap(find.text('Keep'));
    await settle(tester);

    expect(session.status, isA<ChangedElsewhere>());
    expect(fixture.onDisk('a.md'), 'theirs, newer\n');
    expect(find.text('Keep this'), findsNWidgets(2));
  });

  testWidgets('shows a newer version from elsewhere', (tester) async {
    await pumpCompare(tester);

    await changedAgain(tester, 'theirs, newer\n');

    // In both panes: as this version's line and as the other's.
    expect(find.textContaining('theirs, newer'), findsNWidgets(2));
  });
}
