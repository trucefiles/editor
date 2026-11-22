import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_file_page/truce_file_page.dart';
import 'package:truce_image_view/truce_image_view.dart';
import 'package:truce_images/truce_images.dart';
import 'package:truce_test_support/truce_test_support.dart';

void main() {
  test('a photo is named by when it was taken', () {
    expect(
      photoName(DateTime(2026, 1, 2, 3, 4, 5)),
      'Photo 2026-01-02 03-04-05',
    );
  });

  /// What the user adds through [picking], picking [choose] if offered
  /// several sources; the hints they see go to [hints].
  Future<NewContent?> add(
    WidgetTester tester,
    FakePicking picking, {
    String? choose,
    List<String>? hints,
  }) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (built) {
            context = built;
            return const SizedBox();
          },
        ),
      ),
    );
    final made = askForImage(
      context,
      picking,
      hint: (message) => hints?.add(message),
      now: () => DateTime(2026, 11, 20, 13, 5, 9),
      prepare: (bytes, settings) async => prepareImage(bytes, settings),
    );
    if (choose != null) {
      await tester.pumpAndSettle();
      await tester.tap(find.text(choose));
    }
    await tester.pumpAndSettle();
    return made;
  }

  testWidgets('a chosen file keeps its name', (tester) async {
    final picking = FakePicking(onePixelPng)..name = 'Cat.jpeg';

    final made = await add(tester, picking);

    expect(made?.name, 'Cat.png');
  });

  testWidgets('a new photo is named by its time', (tester) async {
    final picking = FakePicking(
      onePixelPng,
      sources: const [ImageSource.file, ImageSource.camera],
    );

    final made = await add(tester, picking, choose: 'Take photo');

    expect(picking.asked, [ImageSource.camera]);
    expect(made?.name, 'Photo 2026-11-20 13-05-09.png');
  });

  testWidgets('a file that is no picture is refused, with a hint', (
    tester,
  ) async {
    final hints = <String>[];
    final picking = FakePicking(onePixelPng.sublist(0, 8))..name = 'x.png';

    expect(await add(tester, picking, hints: hints), isNull);
    expect(hints, ["That file isn't an image the app can show."]);
  });
}
