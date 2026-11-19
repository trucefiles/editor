import 'dart:math';

import 'package:truce_core/truce_core.dart';

/// The one rule for where the app keeps document images and how it names
/// them: `document-images/img-<id>.<extension>` at a folder's root, the
/// id 16 random hex digits. A link whose last part is such a name may be
/// one of ours, wherever it points.
abstract final class ImageNames {
  /// The folder that holds them, at the root.
  static final folder = RelPath.parse('document-images')!;

  /// Whether [path] is the folder or lies inside it: the files the app
  /// keeps apart from the documents.
  static bool isKept(RelPath path) => path.isAtOrInside(folder);

  static final _name = RegExp(r'^img-[0-9a-f]{16}\.(jpg|png|gif|webp|bmp)$');

  /// Every name of ours in any text, links or not; may find more than a
  /// reader would, which only keeps an image.
  static final _inText = RegExp(r'img-[0-9a-f]{16}\.(?:jpg|png|gif|webp|bmp)');

  static final _random = Random.secure();

  /// A new name for an image with [extension] (without its dot).
  static String newName(String extension) {
    final id = [for (var i = 0; i < 8; i++) _random.nextInt(256)]
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'img-$id.$extension';
  }

  /// The name [link] ends in, if it is one of ours; `null` for any other
  /// link (one with a scheme, a query or another name).
  static String? nameIn(String link) {
    final uri = Uri.tryParse(link);
    if (uri == null || uri.hasScheme || uri.hasQuery || uri.hasFragment) {
      return null;
    }
    final name = uri.pathSegments.lastOrNull;
    return name != null && _name.hasMatch(name) ? name : null;
  }

  /// The names of ours [text] holds.
  static Set<String> namesIn(String text) => {
    for (final match in _inText.allMatches(text)) match[0]!,
  };

  /// Where the image [name] is kept.
  static RelPath pathOf(String name) => folder.child(name)!;

  /// The link to the image [name] from a document in [documentFolder]
  /// (`null`: the top level).
  static String linkFrom(RelPath? documentFolder, String name) {
    final up = documentFolder == null
        ? ''
        : '../' * (documentFolder.folders.length + 1);
    return '$up${pathOf(name).value}';
  }
}
