import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_images/truce_images.dart';

/// A PNG picture of one pixel.
final onePixelPng = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
  '/pLvAAAAAElFTkSuQmCC',
);

/// Picks [picked] from any source, as the user would.
final class FakePicking implements ImagePicking {
  FakePicking(this.picked, {this.sources = const [ImageSource.file]});

  Uint8List? picked;

  /// The name of the file [picked] came from, if any.
  String? name;

  @override
  final List<ImageSource> sources;

  final List<ImageSource> asked = [];

  /// When set, a pick waits for it, as a dialog open.
  Completer<void>? waits;

  @override
  Future<PickedImage?> pick(ImageSource source) async {
    asked.add(source);
    await waits?.future;
    return switch (picked) {
      final bytes? => (bytes: bytes, name: name),
      null => null,
    };
  }

  @override
  ImageSettings get settings => ImageSettings.standard;
}
