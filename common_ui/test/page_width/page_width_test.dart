import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

void main() {
  group('the side space', () {
    test('is none while the page is not wider than the column', () {
      expect(PageWidth.sideOf(400, TextScaler.noScaling), 0);
      expect(PageWidth.sideOf(640, TextScaler.noScaling), 0);
    });

    test('centers the column on a wide page', () {
      expect(PageWidth.sideOf(1040, TextScaler.noScaling), 200);
    });

    test('shrinks as the text grows', () {
      expect(PageWidth.sideOf(1040, const TextScaler.linear(1.5)), 40);
    });
  });

  testWidgets('hands the side space and the screen insets to the page', (
    tester,
  ) async {
    late EdgeInsets given;
    tester.view.physicalSize = const Size(1040, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(1040, 600),
          padding: EdgeInsets.only(top: 10, bottom: 20),
        ),
        child: PageWidth(
          builder: (_, padding) {
            given = padding;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(given, const EdgeInsets.fromLTRB(200, 10, 200, 20));
  });
}
