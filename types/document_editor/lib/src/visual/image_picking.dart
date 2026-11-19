import 'dart:typed_data';

import 'package:truce_images/truce_images.dart' show ImageSettings;

/// Where a picture can come from.
enum ImageSource {
  /// A file dialog, or the device's file picker.
  file,

  /// The device's photos.
  gallery,

  /// A new photo from the camera.
  camera,
}

/// How the app picks pictures on this device: from the app's wiring.
abstract interface class ImagePicking {
  /// Where pictures can come from here, in the order offered.
  List<ImageSource> get sources;

  /// A picture's bytes from [source], as picked: always a copy; `null`
  /// if none was picked.
  Future<Uint8List?> pick(ImageSource source);

  /// How pictures are made ready, as the device settings say now.
  ImageSettings get settings;
}
