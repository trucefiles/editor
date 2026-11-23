import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truce_common_ui/truce_common_ui.dart';

import 'test_pictures.dart';

/// A picture told apart by [name].
final class _Named extends BytesImage<_Named> {
  const _Named(this.name, {super.size = const Within(1, 1)});

  final String name;

  @override
  Future<Uint8List?> readBytes() async => null;

  @override
  List<Object?> get identity => [name];
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
            image: TestPicture(() => bytes, size: const Within(100, 100)),
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

    bytes = onePixel;
    await tester.pumpWidget(const SizedBox());
    await show();

    expect(find.text('broken'), findsNothing);
  });
}
