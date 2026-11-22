import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_editor/file_page/ui/view_under_banners.dart';

void main() {
  /// The page with [banners] as tall as given, over a view that shows
  /// its top padding.
  Widget page(List<double> banners) => MaterialApp(
    home: ViewUnderBanners(
      banners: [for (final height in banners) SizedBox(height: height)],
      view: Builder(
        builder: (context) =>
            Text('${MediaQuery.paddingOf(context).top}', key: const Key('v')),
      ),
    ),
  );

  String padding(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('v'))).data!;

  testWidgets('the view fills the page under the banners', (tester) async {
    await tester.pumpWidget(page([40]));

    expect(tester.getTopLeft(find.byKey(const Key('v'))).dy, 0);
  });

  testWidgets("the view's top padding follows the banners as they change", (
    tester,
  ) async {
    await tester.pumpWidget(page([40]));
    await tester.pump();
    expect(padding(tester), '40.0');

    await tester.pumpWidget(page([40, 30]));
    await tester.pump();
    expect(padding(tester), '70.0');

    await tester.pumpWidget(page([]));
    await tester.pump();
    expect(padding(tester), '0.0');
  });
}
