import 'dart:convert';
import 'dart:typed_data';

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
  const _Picture(this.read, {super.size});

  final Uint8List? Function() read;

  @override
  Future<Uint8List?> readBytes() async => read();

  @override
  bool operator ==(Object other) => other is _Picture && other.size == size;

  @override
  int get hashCode => size.hashCode;
}

void main() {
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
}
