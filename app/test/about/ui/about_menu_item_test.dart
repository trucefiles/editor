import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/about/app_version.dart';
import 'package:truce_editor/about/ui/about_menu_item.dart';
import 'package:truce_editor/platform/link_opener.dart';

void main() {
  late _FakeLinkOpener links;

  setUp(() => links = _FakeLinkOpener());

  Future<void> openAbout(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((_) async => '1.2.3'),
          linkOpenerProvider.overrideWithValue(links),
        ],
        child: MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                Consumer(
                  builder: (context, ref, _) => PopupMenuButton<VoidCallback>(
                    onSelected: (action) => action(),
                    itemBuilder: (_) => [aboutMenuItem(context, ref)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<VoidCallback>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the version and license', (tester) async {
    await openAbout(tester);

    expect(find.text('Version 1.2.3'), findsOneWidget);
    expect(find.textContaining('GPL-3.0'), findsOneWidget);
  });

  testWidgets('opens the source code link', (tester) async {
    await openAbout(tester);

    await tester.tap(find.text('Source code'));
    await tester.pumpAndSettle();

    expect(links.opened, [sourceLink]);
  });

  testWidgets('tells when no app opens the link', (tester) async {
    links.opens = false;
    await openAbout(tester);

    await tester.tap(find.text('Source code'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No app could open'), findsOneWidget);
  });
}

final class _FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];
  bool opens = true;

  @override
  Future<bool> open(Uri link) async {
    opened.add(link);
    return opens;
  }
}
