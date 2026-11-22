import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

/// A PNG of one pixel.
final _onePixel = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

/// A picture whose bytes [read] gives, at [size].
final class _Picture extends BytesImage<_Picture> {
  const _Picture(this.read, {required super.size});

  final Uint8List? Function() read;

  @override
  Future<Uint8List?> readBytes() async => read();

  @override
  List<Object?> get identity => const [];
}

/// A picture told apart by [name].
final class _Named extends BytesImage<_Named> {
  const _Named(this.name, {super.size = const Within(1, 1)});

  final String name;

  @override
  Future<Uint8List?> readBytes() async => null;

  @override
  List<Object?> get identity => [name];
}

/// A picture whose bytes never come.
final class _Pending extends BytesImage<_Pending> {
  const _Pending({required super.size});

  @override
  Future<Uint8List?> readBytes() => Completer<Uint8List?>().future;

  @override
  List<Object?> get identity => const ['pending'];
}

void main() {
  test('pictures are equal by their identity and their size', () {
    expect(
      const _Named('a', size: Within(1, 1)),
      const _Named('a', size: Within(1, 1)),
    );
    expect(const _Named('a').hashCode, const _Named('a').hashCode);
    expect(const _Named('a'), isNot(const _Named('b')));
    expect(const _Named('a'), isNot(const _Named('a', size: Within(2, 1))));
  });

  group('a picture covering a box', () {
    const box = Covering(400, 300);

    test('decodes as high as the box when wide, its sides cut', () {
      final size = box.targetFor(5000, 1000);

      expect((size.width, size.height), (1500, 300));
    });

    test('decodes as wide as the box when tall', () {
      final size = box.targetFor(1000, 4000);

      expect((size.width, size.height), (400, 1600));
    });

    test('decodes as it is when smaller than the box', () {
      final size = box.targetFor(200, 100);

      expect((size.width, size.height), (null, null));
    });
  });

  group('a picture within a box', () {
    const box = Within(400, 300);

    test('decodes as wide as the box when wide', () {
      final size = box.targetFor(8000, 1000);

      expect((size.width, size.height), (400, 50));
    });

    test('decodes as high as the box when tall', () {
      final size = box.targetFor(1000, 6000);

      expect((size.width, size.height), (50, 300));
    });

    test('decodes as it is when smaller than the box', () {
      final size = box.targetFor(200, 100);

      expect((size.width, size.height), (null, null));
    });
  });

  testWidgets('a picture that could not be read is read again as it shows '
      'again', (tester) async {
    Uint8List? bytes;
    Future<void> show() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Image(
            image: _Picture(() => bytes, size: const Within(100, 100)),
            errorBuilder: (_, _, _) => const Text('broken'),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
    }

    await show();
    expect(find.text('broken'), findsOne);

    bytes = _onePixel;
    await tester.pumpWidget(const SizedBox());
    await show();

    expect(find.text('broken'), findsNothing);
  });

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
          return _Picture(() => _onePixel, size: size);
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

  testWidgets('a double tap zooms in on its spot, the next one goes back '
      'to fit', (tester) async {
    await tester.pumpWidget(_zoomable());
    const spot = Offset(100, 150);
    Matrix4 shown() => tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;

    await _doubleTap(tester, spot);

    expect(shown().getMaxScaleOnAxis(), ZoomableImage.tapZoom);
    expect(MatrixUtils.transformPoint(shown(), spot), spot);

    await _doubleTap(tester, const Offset(300, 400));

    expect(shown(), Matrix4.identity());
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

    await show((size) => _Picture(() => _onePixel, size: size));
    expect(drawn().image, isNotNull);

    await show((size) => _Pending(size: size));

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
      (size) => _Picture(() => _onePixel, size: size),
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
