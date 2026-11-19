import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:truce_document_editor/truce_document_editor.dart';
import 'package:truce_images/truce_images.dart';

/// Picks pictures on this platform from [sources]: a file dialog (on
/// Linux through the desktop portal), the device's photos or its camera;
/// made ready as [settings] says now.
final class PlatformImagePicking implements ImagePicking {
  PlatformImagePicking({required this.sources, required this.read});

  @override
  final List<ImageSource> sources;

  /// The device's image settings as they are now.
  final ImageSettings Function() read;

  @override
  ImageSettings get settings => read();

  @override
  Future<Uint8List?> pick(ImageSource source) async {
    try {
      return switch (source) {
        ImageSource.file => await (await openFile(
          acceptedTypeGroups: [_images],
        ))?.readAsBytes(),
        ImageSource.gallery => await _picked(picker.ImageSource.gallery),
        ImageSource.camera => await _picked(picker.ImageSource.camera),
      };
    } on PlatformException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Future<Uint8List?> _picked(picker.ImageSource source) async =>
      (await picker.ImagePicker().pickImage(source: source))?.readAsBytes();
}

const _images = XTypeGroup(
  label: 'Images',
  extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'],
  mimeTypes: [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'image/bmp',
  ],
  uniformTypeIdentifiers: ['public.image'],
);
