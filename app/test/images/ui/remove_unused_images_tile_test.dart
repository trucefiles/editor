import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/images/image_cleanup.dart';
import 'package:truce_editor/images/images_wiring.dart';
import 'package:truce_editor/images/ui/remove_unused_images_tile.dart';
import 'package:truce_markdown_images/truce_markdown_images.dart';

import '../../support.dart';

/// Frames enough for a dialog to open or close; the tile's spinner
/// never settles while it asks.
Future<void> settle(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _FakeCleanup cleanup;

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [imageCleanupProvider.overrideWithValue(cleanup)],
      child: MaterialApp(
        home: Scaffold(body: RemoveUnusedImagesTile(folderId('f1'))),
      ),
    ),
  );

  FileEntry image(String name) => FileEntry(
    path('document-images/$name'),
    version: const FileVersion(1),
    modified: DateTime(2026),
    size: 0,
  );

  testWidgets('asks with how many, then removes them', (tester) async {
    cleanup = _FakeCleanup(Ok([image('a'), image('b')]));
    await pump(tester);

    await tester.tap(find.text('Remove unused images'));
    await settle(tester);
    expect(find.text('Remove 2 unused images?'), findsOne);
    await tester.tap(find.text('Remove'));
    await settle(tester);

    expect(cleanup.removed, hasLength(2));
    expect(find.text('Removed 2 images.'), findsOne);
  });

  testWidgets('Cancel removes nothing', (tester) async {
    cleanup = _FakeCleanup(Ok([image('a')]));
    await pump(tester);

    await tester.tap(find.text('Remove unused images'));
    await settle(tester);
    await tester.tap(find.text('Cancel'));
    await settle(tester);

    expect(cleanup.removed, isEmpty);
  });

  testWidgets('tells when none are unused', (tester) async {
    cleanup = _FakeCleanup(const Ok([]));
    await pump(tester);

    await tester.tap(find.text('Remove unused images'));
    await settle(tester);

    expect(find.text('No unused images.'), findsOne);
  });

  testWidgets('removes nothing if not every document could be read', (
    tester,
  ) async {
    cleanup = _FakeCleanup(const Err(CleanupRefused.notAllRead));
    await pump(tester);

    await tester.tap(find.text('Remove unused images'));
    await settle(tester);

    expect(find.textContaining("Couldn't read every document"), findsOne);
    expect(cleanup.removed, isEmpty);
  });
}

final class _FakeCleanup implements ImageCleanup {
  _FakeCleanup(this.found);

  final Result<List<FileEntry>, CleanupRefused> found;
  final List<FileEntry> removed = [];

  @override
  Future<Result<List<FileEntry>, CleanupRefused>> find(FolderId folder) async =>
      found;

  @override
  Future<int> remove(FolderId folder, List<FileEntry> images) async {
    removed.addAll(images);
    return images.length;
  }
}
