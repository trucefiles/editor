import 'package:flutter/foundation.dart';
import 'package:truce_common_ui/truce_common_ui.dart';
import 'package:truce_file_page/truce_file_page.dart';

/// The picture [content] holds, read when first shown, decoded at [size]
/// (see [BytesImage]); kept in Flutter's image cache by its id, so
/// another version is read anew.
@immutable
final class ContentImage extends BytesImage<ContentImage> {
  const ContentImage(this.content, {super.size});

  final ShownContent content;

  @override
  Future<Uint8List?> readBytes() => content.read();

  @override
  bool operator ==(Object other) =>
      other is ContentImage &&
      other.content.id == content.id &&
      other.size == size;

  @override
  int get hashCode => Object.hash(content.id, size);
}
