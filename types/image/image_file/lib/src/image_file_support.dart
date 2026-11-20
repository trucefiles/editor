import 'package:truce_core/truce_core.dart';

/// Pictures.
const imageType = FileType('image');

/// What the app knows of picture files: the kinds it shows, by
/// extension; a new one takes its picture's own.
final class ImageFileSupport implements FileTypeSupport {
  const ImageFileSupport();

  @override
  FileType get type => imageType;

  @override
  Set<String> get extensions => const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'bmp',
  };
}
