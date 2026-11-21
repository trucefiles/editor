import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/files/ui/file_actions_menu.dart';

import '../../support.dart';

void main() {
  testWidgets("a card's sheet fits a phone on its side, its colors "
      'reachable by scrolling', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final file = listedFile(folderAt(Directory('/documents')), name: 'Plan.md');
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HomeFileActions(
              file,
              title: 'Plan',
              pinned: false,
              color: null,
              builder: (showSheet, _) =>
                  TextButton(onPressed: showSheet, child: const Text('open')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.textContaining('Open the file to move'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('Open the file to move'), findsOne);
  });
}
