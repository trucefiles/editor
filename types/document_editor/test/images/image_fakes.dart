import 'dart:convert';
import 'dart:typed_data';

import 'package:truce_core/truce_core.dart';
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_file_page/truce_file_page.dart';
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

  @override
  final List<ImageSource> sources;

  final List<ImageSource> asked = [];

  @override
  Future<Uint8List?> pick(ImageSource source) async {
    asked.add(source);
    return picked;
  }

  @override
  ImageSettings get settings => ImageSettings.standard;
}

/// Keeps images in memory, named by count; fails with [failWith].
final class FakeKept implements HostImages {
  final Map<String, Uint8List> kept = {};
  StoreError? failWith;

  @override
  RelPath? keptAt(String link) => null;

  @override
  Future<Result<String, StoreError>> add(
    Uint8List bytes, {
    required String extension,
  }) async {
    if (failWith case final error?) return Err(error);
    final link = 'kept/${kept.length + 1}.$extension';
    kept[link] = bytes;
    return Ok(link);
  }
}
