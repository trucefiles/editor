import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_local_folder/truce_local_folder.dart';
import 'package:truce_local_folder_ui/truce_local_folder_ui.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late Directory dir;
  late LocalFolderPlugin plugin;
  List<PluginFolderCandidate>? result;

  setUp(() {
    dir = tempFolder();
    plugin = LocalFolderPlugin(
      LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
        hostPaths: const SameHostPaths(),
      ),
    )..load(null);
    result = null;
  });

  /// Runs the page, the user picking [picked].
  Future<void> run(WidgetTester tester, Uri? picked) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await addLocalFolder(
                context,
                plugin: plugin,
                pick: () async => picked,
              ),
              child: const Text('Add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    for (var round = 0; round < 5; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('gives the picked folder', (tester) async {
    Directory('${dir.path}/notes').createSync();

    await run(tester, Uri.directory('${dir.path}/notes'));

    expect(result!.single.defaultName, 'notes');
  });

  testWidgets('tells why a pick in a hidden folder is refused', (tester) async {
    Directory('${dir.path}/.stversions/old').createSync(recursive: true);

    await run(tester, Uri.directory('${dir.path}/.stversions/old'));

    expect(result, isNull);
    expect(find.textContaining('hidden folder'), findsOneWidget);
  });

  testWidgets('gives nothing when the pick is cancelled', (tester) async {
    await run(tester, null);

    expect(result, isNull);
  });
}
