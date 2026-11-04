import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/folders/open_folders_wiring.dart';
import 'package:truce_editor/folders/ui/folders_screen.dart';
import 'package:truce_folders/truce_folders.dart';

import '../../support.dart';

void main() {
  testWidgets('scrolled to the end, the Add button covers no folder', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(360, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final folders = [
      for (var index = 0; index < 12; index++)
        folderAt(tempFolder(), id: 'f$index'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => _Folders(folders)),
          folderListStateProvider.overrideWith(() => _Loaded(folders)),
          folderNoticesProvider.overrideWith(
            (ref, _) async => const <FolderNotice>[],
          ),
        ],
        child: const MaterialApp(home: FoldersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
    await tester.pumpAndSettle();

    final last = tester.getRect(find.byType(ListTile).last);
    final button = tester.getRect(find.byType(FloatingActionButton));
    expect(last.bottom, lessThanOrEqualTo(button.top));
  });
}

final class _Folders extends FoldersController {
  _Folders(this.folders);

  final List<Folder> folders;

  @override
  Future<List<Folder>> build() async => folders;
}

final class _Loaded extends FolderListStateController {
  _Loaded(this.folders);

  final List<Folder> folders;

  @override
  FolderListState build() => FoldersLoaded(folders);
}
