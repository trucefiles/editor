import 'package:flutter_test/flutter_test.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_editor/refresh/ui/pull_to_refresh.dart';
import 'package:truce_editor_test_support/truce_editor_test_support.dart';
import 'package:truce_markdown/truce_markdown.dart' show EditMode;

/// Pulling an open document down refreshes, in every mode: the editor
/// scrolls inside the pull.
void main() {
  /// Shows [text] in [mode] inside a pull; tells how often it refreshed.
  Future<int Function()> pumpPull(
    WidgetTester tester,
    String text,
    EditMode mode,
  ) async {
    var refreshes = 0;
    await pumpDocument(
      tester,
      TestDocument(text, mode: mode),
      around: (context, child) =>
          PullToRefresh(onRefresh: () async => refreshes++, child: child!),
    );
    await tester.pumpAndSettle();
    return () => refreshes;
  }

  testWidgets('in Read, a drag on the text scrolls the document, never '
      'refreshes', (tester) async {
    final refreshes = await pumpPull(
      tester,
      [for (final line in Iterable<int>.generate(60)) 'line $line']
          .join('\n\n'),
      EditMode.read,
    );
    Finder line(int index) => find.text('line $index', findRichText: true);

    await tester.drag(line(5), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(line(0), findsNothing, reason: 'scrolled down');

    await tester.drag(line(15), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(refreshes(), 0);
  });

  for (final mode in EditMode.values) {
    testWidgets('pulling down by touch refreshes in ${mode.name}', (
      tester,
    ) async {
      final refreshes = await pumpPull(tester, '- [ ] milk\neggs', mode);

      await tester.fling(
        find.byType(DocumentEditor),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(refreshes(), 1);
    });
  }
}
