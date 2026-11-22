import 'dart:typed_data';

import 'prepare_image.dart';

/// Where a picture can come from.
enum ImageSource {
  /// A file dialog, or the device's file picker.
  file,

  /// The device's photos.
  gallery,

  /// A new photo from the camera.
  camera,
}

/// A picture as the user picked it: its [bytes], and the [name] of its
/// file where it has one the user knows (e.g. `beach.jpg`; none for a
/// new photo, or where the platform hides it).
typedef PickedImage = ({Uint8List bytes, String? name});

/// How the app picks pictures on this device: from the app's wiring.
abstract interface class ImagePicking {
  /// Where pictures can come from here, in the order offered.
  List<ImageSource> get sources;

  /// A picture from [source], as picked: always a copy; `null` if none
  /// was picked.
  Future<PickedImage?> pick(ImageSource source);

  /// How pictures are made ready, as the device settings say now.
  ImageSettings get settings;
}
