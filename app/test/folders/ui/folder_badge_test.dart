import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/folders/ui/folder_badge.dart';

import '../../support.dart';

void main() {
  final folder = folderAt(Directory('/documents'));

  Future<void> show(WidgetTester tester, FolderBadge badge) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: badge)));

  testWidgets('shows the folder name alone', (tester) async {
    await show(tester, FolderBadge(folder));

    expect(find.text('Documents'), findsOne);
  });

  testWidgets('shows only the folder name for a file at its root', (
    tester,
  ) async {
    await show(tester, FolderBadge(folder, file: path('todo.md')));

    expect(find.text('Documents'), findsOne);
  });

  testWidgets('shows the subfolders a file is in', (tester) async {
    await show(tester, FolderBadge(folder, file: path('a/b/c/todo.md')));

    expect(find.text('Documents/a/b/c'), findsOne);
  });

  group('placeNames', () {
    test('cut in the middle, the folder name last', () {
      expect(placeNames(folder, path('a/b/c')), [
        'Documents/a/b/c',
        'Documents/…/c',
        'Documents/…',
      ]);
      expect(placeNames(folder, path('a')), ['Documents/a', 'Documents/…']);
      expect(placeNames(folder, null), ['Documents']);
    });
  });

  testWidgets('shows the full place on hover', (tester) async {
    await show(tester, FolderBadge(folder, file: path('a/b/c/todo.md')));

    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).message,
      'Documents/a/b/c',
    );
  });

  testWidgets('shows nothing, not overflowing, where not even its dot fits', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 8,
              child: FolderBadge(
                folder,
                file: path('a/todo.md'),
                cutInMiddle: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(FolderDot), findsNothing);
  });
}
