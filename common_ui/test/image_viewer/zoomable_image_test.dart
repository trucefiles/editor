import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import 'test_pictures.dart';

void main() {
  testWidgets('the zoomable view decodes at most three screens, and never '
      'past its largest side', (tester) async {
    tester.view
      ..physicalSize = const Size(1000, 2000)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final asked = <Within>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ZoomableImage((size) {
          asked.add(size);
          return TestPicture(() => onePixel, size: size);
        }, alt: 'a picture'),
      ),
    );

    expect(asked.last, const Within(3000, DecodeSize.largestSide));
  });

  testWidgets('at fit, the zoomable view stays in place when dragged, '
      'even with its top covered', (tester) async {
    await tester.pumpWidget(_zoomable(topCovered: 50));

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(Image)).dy, 0);
  });

  testWidgets('zoomed in, it moves down as far as its top is covered', (
    tester,
  ) async {
    await tester.pumpWidget(_zoomable(topCovered: 50));
    await _doubleTap(tester, const Offset(200, 0));

    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(Image)).dy, 50);
  });

  testWidgets('zoomed back out, it settles at fit, never staying moved', (
    tester,
  ) async {
    await tester.pumpWidget(_zoomable(topCovered: 50));
    await _doubleTap(tester, const Offset(200, 0));
    await tester.drag(find.byType(InteractiveViewer), const Offset(0, 200));
    await tester.pumpAndSettle();

    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    tester.binding.handlePointerEvent(mouse.hover(const Offset(200, 300)));
    tester.binding.handlePointerEvent(mouse.scroll(const Offset(0, 400)));
    await tester.pumpAndSettle();

    expect(_shown(tester), Matrix4.identity());
  });

  testWidgets('a double tap zooms in on its spot, the next one goes back '
      'to fit', (tester) async {
    await tester.pumpWidget(_zoomable());
    const spot = Offset(100, 150);

    await _doubleTap(tester, spot);

    expect(_shown(tester).getMaxScaleOnAxis(), ZoomableImage.tapZoom);
    expect(MatrixUtils.transformPoint(_shown(tester), spot), spot);

    await _doubleTap(tester, const Offset(300, 400));

    expect(_shown(tester), Matrix4.identity());
  });

  testWidgets('the zoomable view keeps showing a picture until the next '
      'one is drawn', (tester) async {
    Future<void> show(SizedImage image) async {
      await tester.pumpWidget(
        MaterialApp(home: ZoomableImage(image, alt: 'a picture')),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    RawImage drawn() => tester.widget(find.byType(RawImage));

    await show((size) => TestPicture(() => onePixel, size: size));
    expect(drawn().image, isNotNull);

    await show((size) => PendingPicture(size: size));

    expect(drawn().image, isNotNull);
  });
}

/// A zoomable picture on a 400 by 600 screen whose top [topCovered] is
/// drawn over.
Widget _zoomable({double topCovered = 0}) => MediaQuery(
  data: MediaQueryData(
    size: const Size(400, 600),
    padding: EdgeInsets.only(top: topCovered),
  ),
  child: MaterialApp(
    home: ZoomableImage(
      (size) => TestPicture(() => onePixel, size: size),
      alt: 'a picture',
    ),
  ),
);

/// Two taps at [spot], close enough to be a double tap, and the zoom
/// after it.
Future<void> _doubleTap(WidgetTester tester, Offset spot) async {
  await tester.tapAt(spot);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(spot);
  await tester.pumpAndSettle();
}

/// How the zoomable view shows its picture now.
Matrix4 _shown(WidgetTester tester) => tester
    .widget<InteractiveViewer>(find.byType(InteractiveViewer))
    .transformationController!
    .value;
