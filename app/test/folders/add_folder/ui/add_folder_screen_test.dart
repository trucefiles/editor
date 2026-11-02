import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_core/truce_core.dart';
import 'package:truce_editor/folders/add_folder/ui/add_folder_screen.dart';
import 'package:truce_editor/folders/folders_controller.dart';
import 'package:truce_editor/plugins/plugins_wiring.dart';
import 'package:truce_editor/plugins/wired_plugin.dart';
import 'package:truce_folders/truce_folders.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  late List<(String, List<NamedCandidate>)> added;
  late Result<List<Folder>, FolderError> answer;
  late List<PluginFolderCandidate>? given;

  setUp(() {
    added = [];
    answer = const Ok([]);
    given = [FakePlugin.candidate('notes')];
  });

  /// Opens the screen over a home page; the plugin `fake`'s add page gives
  /// [given].
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          foldersProvider.overrideWith(() => _Folders(added, () => answer)),
          wiredPluginsProvider.overrideWithValue([
            WiredPlugin(FakePlugin(), (_) async => given),
            WiredPlugin(FakePlugin('other'), (_) async => null),
          ]),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AddFolderScreen(),
                ),
              ),
              child: Text(
                ref.watch(foldersProvider).hasValue ? 'home' : 'loading',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the plugins with their help lines', (tester) async {
    await open(tester);

    expect(find.text('Fake fake'), findsOne);
    expect(find.text('Fake other'), findsOne);
    expect(find.text('Folders in memory'), findsNWidgets(2));
  });

  testWidgets('adds the folders the page gave, named in turn', (tester) async {
    given = [FakePlugin.candidate('notes'), FakePlugin.candidate('work')];
    await open(tester);

    await tester.tap(find.text('Fake fake'));
    await tester.pumpAndSettle();
    expect(find.text('Folder 1 of 2'), findsOne);
    expect(find.widgetWithText(TextFormField, 'notes'), findsOne);
    await tester.enterText(find.byType(TextFormField), 'Notes');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'work'), findsOne);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    final (plugin, candidates) = added.single;
    expect(plugin, 'fake');
    expect([for (final named in candidates) named.name], ['Notes', 'work']);
    expect(find.byType(AddFolderScreen), findsNothing);
  });

  testWidgets('a page cancelled stays at the plugins', (tester) async {
    await open(tester);

    await tester.tap(find.text('Fake other'));
    await tester.pumpAndSettle();

    expect(find.text('Fake fake'), findsOne);
    expect(added, isEmpty);
  });

  testWidgets('a refused add stays on the screen and says why', (tester) async {
    answer = const Err(FolderError.notSaved);
    await open(tester);
    await tester.tap(find.text('Fake fake'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      find.text('The folder list could not be saved, so nothing changed.'),
      findsOne,
    );
    expect(find.byType(AddFolderScreen), findsOne);
  });

  testWidgets('back goes one step back, then leaves', (tester) async {
    await open(tester);
    await tester.tap(find.text('Fake fake'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Fake fake'), findsOne);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AddFolderScreen), findsNothing);
  });
}

/// No folders added before; adds go to [added], answered by [answer].
final class _Folders extends FoldersController {
  _Folders(this.added, this.answer);

  final List<(String, List<NamedCandidate>)> added;
  final Result<List<Folder>, FolderError> Function() answer;

  @override
  Future<List<Folder>> build() async => const [];

  @override
  Future<Result<List<Folder>, FolderError>> add(
    FolderPlugin plugin,
    List<NamedCandidate> candidates,
  ) async {
    added.add((plugin.id, candidates));
    return answer();
  }
}
