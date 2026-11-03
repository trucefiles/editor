import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_syncthing/truce_syncthing.dart';
import 'package:truce_syncthing_ui/truce_syncthing_ui.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late Directory root;
  late SyncthingPlugin plugin;

  setUp(() {
    root = tempFolder();
    Directory('${root.path}/work/a').createSync(recursive: true);
    Directory('${root.path}/notes').createSync();
    var ids = 0;
    plugin = SyncthingPlugin(
      LocalDisk(
        replacesInPlace: false,
        followsLive: (_) => false,
        seesParents: (_) => true,
        hostPaths: const SameHostPaths(),
      ),
      newId: () => 'id${ids++}',
    )..load(null);
  });

  /// What the page gave, once it ended.
  late List<PluginFolderCandidate>? result;
  late bool ended;

  /// Opens the add page, the user picking [picked].
  Future<void> open(WidgetTester tester, Uri? picked) async {
    ended = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await addSyncthingFolders(
                  context,
                  plugin: plugin,
                  pick: () async => picked,
                );
                ended = true;
              },
              child: const Text('Add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Add'));
    await _settle(tester);
  }

  testWidgets('ticks the picked folder in its Syncthing folder', (
    tester,
  ) async {
    File('${root.path}/.stfolder').createSync();

    await open(tester, Uri.directory('${root.path}/work'));
    expect(find.text('work'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await _settle(tester);

    expect([for (final c in result!) c.defaultName], ['work']);
  });

  testWidgets('goes on with the pick as the Syncthing folder when none is '
      'found', (tester) async {
    await open(tester, Uri.directory(root.path));
    await tester.tap(find.text('Continue with this folder'));
    await _settle(tester);
    await tester.tap(find.text('Next'));
    await _settle(tester);

    expect(result!.single.location, contains('(Syncthing folder '));
  });

  testWidgets('never goes on with a pick inside a hidden folder', (
    tester,
  ) async {
    Directory('${root.path}/.stversions/old').createSync(recursive: true);

    await open(tester, Uri.directory('${root.path}/.stversions/old'));
    await tester.tap(find.text('Continue with this folder'));
    await _settle(tester);

    expect(find.text('Folders to add'), findsNothing);
    expect(
      find.text("Hidden folders and Syncthing's own can't be added."),
      findsOneWidget,
    );
    expect(ended, isTrue);
    expect(result, isNull);
  });

  testWidgets('names the folder added before that a new one lies around', (
    tester,
  ) async {
    final work = Uri.directory('${root.path}/work');
    plugin.add([plugin.candidate(work, work, null)]);
    File('${root.path}/.stfolder').createSync();

    await open(tester, Uri.directory('${root.path}/notes'));

    expect(
      find.text(
        'This Syncthing folder overlaps ${shownAddress(work)}, which is '
        'already in the app. Remove that one first to add this one.',
      ),
      findsOneWidget,
    );
    expect(result, isNull);
  });

  testWidgets('gives nothing when the pick is cancelled', (tester) async {
    await open(tester, null);

    expect(ended, isTrue);
    expect(result, isNull);
  });
}

/// Lets the page's disk reads land, then its frames.
Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 10; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }
}
