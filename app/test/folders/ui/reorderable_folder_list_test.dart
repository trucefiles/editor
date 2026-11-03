import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/ui/reorderable_folder_list.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../support.dart';

void main() {
  final a = Folder(id: folderId('a'), name: 'A', color: 'teal', location: 'a');
  final b = Folder(id: folderId('b'), name: 'B', color: 'teal', location: 'b');

  /// Shows [a] and [b]; each move waits for [saved].
  Future<void> show(WidgetTester tester, Future<bool> saved) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReorderableFolderList(
              [a, b],
              onMove: (_, _) => saved,
              tile: (folder, index) => ListTile(
                key: ValueKey(folder.id),
                title: Text(folder.name),
                trailing: ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              ),
            ),
          ),
        ),
      );

  /// Drags B above A.
  Future<void> dragBUp(WidgetTester tester) async {
    final handle = find.byIcon(Icons.drag_handle);
    await tester.timedDrag(
      handle.last,
      tester.getCenter(handle.first) - tester.getCenter(handle.last),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
  }

  double top(WidgetTester tester, String name) =>
      tester.getTopLeft(find.text(name)).dy;

  testWidgets('a dropped folder stays put while the move is saved', (
    tester,
  ) async {
    await show(tester, Completer<bool>().future);

    await dragBUp(tester);

    expect(top(tester, 'B'), lessThan(top(tester, 'A')));
  });

  testWidgets('a dropped folder goes back if the move is not saved', (
    tester,
  ) async {
    await show(tester, Future.value(false));

    await dragBUp(tester);

    expect(top(tester, 'A'), lessThan(top(tester, 'B')));
  });
}
