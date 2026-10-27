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
}
