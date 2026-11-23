import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_common_ui/truce_common_ui.dart';

/// A PNG of one pixel.
final onePixel = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

/// A picture whose bytes [read] gives, at [size].
final class TestPicture extends BytesImage<TestPicture> {
  const TestPicture(this.read, {required super.size});

  final Uint8List? Function() read;

  @override
  Future<Uint8List?> readBytes() async => read();

  @override
  List<Object?> get identity => const [];
}

/// A picture whose bytes never come.
final class PendingPicture extends BytesImage<PendingPicture> {
  const PendingPicture({required super.size});

  @override
  Future<Uint8List?> readBytes() => Completer<Uint8List?>().future;

  @override
  List<Object?> get identity => const ['pending'];
}
