import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/reach/folder_reach_controller.dart';
import 'package:truce_editor/reach/ui/reach_overlay.dart';
import 'package:truce_editor/reach/ui/unreachable_banner.dart';

import '../../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));

  group('overlay', () {
    Future<void> pumpOverlay(WidgetTester tester, {required bool retrying}) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              retryingFoldersProvider.overrideWithValue(
                retrying ? [folder] : const [],
              ),
            ],
            child: MaterialApp(
              builder: (_, child) => ReachOverlay(child: child!),
              home: Scaffold(
                body: TextButton(
                  onPressed: () => throw StateError('tapped'),
                  child: const Text('Act'),
                ),
              ),
            ),
          ),
        );

    testWidgets('blocks input and names the folder while retrying', (
      tester,
    ) async {
      await pumpOverlay(tester, retrying: true);

      expect(find.text('Trying to reach Documents…'), findsOneWidget);
      await tester.tap(find.text('Act'), warnIfMissed: false);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows nothing otherwise', (tester) async {
      await pumpOverlay(tester, retrying: false);

      expect(find.textContaining('Trying to reach'), findsNothing);
      await tester.tap(find.text('Act'));
      expect(tester.takeException(), isStateError);
    });
  });

  group('banner', () {
    Future<void> pumpBanner(WidgetTester tester, Reach reach) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              folderReachProvider(folder.location)
                  .overrideWith(() => _FixedReach(folder.location, reach)),
            ],
            child: MaterialApp(
              home: Scaffold(body: UnreachableBanner(folder, message: 'Wait.')),
            ),
          ),
        );

    testWidgets('tells that the folder cannot be reached', (tester) async {
      await pumpBanner(tester, Reach.unreachable);

      expect(find.text("Documents can't be reached. Wait."), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows nothing while it can', (tester) async {
      await pumpBanner(tester, Reach.reachable);

      expect(find.byType(MaterialBanner), findsNothing);
    });
  });
}

final class _FixedReach extends FolderReachController {
  _FixedReach(super.location, this._reach);

  final Reach _reach;

  @override
  Reach build() => _reach;
}
