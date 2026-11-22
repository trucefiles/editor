import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart' as picker;
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
  Future<PickedImage?> pick(ImageSource source) async {
    try {
      return switch (source) {
        ImageSource.file => await _named(
          await openFile(acceptedTypeGroups: [_images]),
        ),
        ImageSource.gallery => await _named(
          await picker.ImagePicker().pickImage(
            source: picker.ImageSource.gallery,
          ),
        ),
        // A new photo has no name of its own.
        ImageSource.camera => switch (await picker.ImagePicker().pickImage(
          source: picker.ImageSource.camera,
        )) {
          final photo? => (bytes: await photo.readAsBytes(), name: null),
          null => null,
        },
      };
    } on PlatformException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// [file] with its name; `null` if none was picked.
  static Future<PickedImage?> _named(XFile? file) async => switch (file) {
    final file? => (bytes: await file.readAsBytes(), name: file.name),
    null => null,
  };
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
