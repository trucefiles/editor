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
        // The device's photo picker hides a photo's own name (Android
        // gives a number instead), and a new photo has none.
        ImageSource.gallery => await _unnamed(
          await picker.ImagePicker().pickImage(
            source: picker.ImageSource.gallery,
          ),
        ),
        ImageSource.camera => await _unnamed(
          await picker.ImagePicker().pickImage(
            source: picker.ImageSource.camera,
          ),
        ),
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

  /// [file] without a name of its own; `null` if none was picked.
  static Future<PickedImage?> _unnamed(XFile? file) async => switch (file) {
    final file? => (bytes: await file.readAsBytes(), name: null),
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
